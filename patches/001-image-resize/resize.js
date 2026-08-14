const sharp = require('sharp');
const { EModelEndpoint } = require('librechat-data-provider');

/**
 * Resizes an image from a given buffer based on the specified resolution.
 *
 * @param {Buffer} inputBuffer - The buffer of the image to be resized.
 * @param {'low' | 'high' | {percentage?: number, px?: number}} resolution - The resolution to resize the image to.
 *                                      'low' for a maximum of 512x512 resolution,
 *                                      'high' for a maximum of 768x2000 resolution,
 *                                      or a custom object with percentage or px values.
 * @param {EModelEndpoint} endpoint - Identifier for specific endpoint handling
 * @returns {Promise<{buffer: Buffer, width: number, height: number}>} An object containing the resized image buffer and its dimensions.
 * @throws Will throw an error if the resolution parameter is invalid.
 */
/**
 * DPA+ patch 001 — make the hardcoded resize ceilings configurable.
 *
 * Upstream hardcodes 512 / 768 / 2000 (1568 for Anthropic), applied to every
 * endpoint regardless of what the model behind it can actually accept. The
 * values come from OpenAI's 2023 vision spec. For large-format source material
 * (A0 construction drawings, high-resolution scans) the 768px short-side cap
 * destroys the image long before any model sees it.
 *
 * This reads the same three values from the environment and falls back to the
 * upstream numbers. With no variables set the behaviour is byte-for-byte
 * identical to upstream — that is the whole point, and the reason this patch is
 * offerable upstream as-is.
 *
 * See patches/001-image-resize/README.md
 */
const envInt = (name, fallback) => {
  const raw = process.env[name];
  if (raw == null || raw === '') return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

async function resizeImageBuffer(inputBuffer, resolution, endpoint) {
  const maxLowRes = envInt('IMAGE_MAX_LOW_RES', 512);
  const maxShortSideHighRes = envInt('IMAGE_MAX_SHORT_SIDE', 768);
  const maxLongSideHighRes =
    endpoint === EModelEndpoint.anthropic
      ? envInt('IMAGE_MAX_LONG_SIDE_ANTHROPIC', 1568)
      : envInt('IMAGE_MAX_LONG_SIDE', 2000);

  let customPercent, customPx;
  if (resolution && typeof resolution === 'object') {
    if (typeof resolution.percentage === 'number') {
      customPercent = resolution.percentage;
    } else if (typeof resolution.px === 'number') {
      customPx = resolution.px;
    }
  }

  let newWidth, newHeight;
  let resizeOptions = { fit: 'inside', withoutEnlargement: true };

  if (customPercent != null || customPx != null) {
    // percentage-based resize
    const metadata = await sharp(inputBuffer).metadata();
    if (customPercent != null) {
      newWidth = Math.round(metadata.width * (customPercent / 100));
      newHeight = Math.round(metadata.height * (customPercent / 100));
    } else {
      // pixel max on both sides
      newWidth = Math.min(metadata.width, customPx);
      newHeight = Math.min(metadata.height, customPx);
    }
    resizeOptions.width = newWidth;
    resizeOptions.height = newHeight;
  } else if (resolution === 'low') {
    resizeOptions.width = maxLowRes;
    resizeOptions.height = maxLowRes;
  } else if (resolution === 'high') {
    const metadata = await sharp(inputBuffer).metadata();
    const isWidthShorter = metadata.width < metadata.height;

    if (isWidthShorter) {
      // Width is the shorter side
      newWidth = Math.min(metadata.width, maxShortSideHighRes);
      // Calculate new height to maintain aspect ratio
      newHeight = Math.round((metadata.height / metadata.width) * newWidth);
      // Ensure the long side does not exceed the maximum allowed
      if (newHeight > maxLongSideHighRes) {
        newHeight = maxLongSideHighRes;
        newWidth = Math.round((metadata.width / metadata.height) * newHeight);
      }
    } else {
      // Height is the shorter side
      newHeight = Math.min(metadata.height, maxShortSideHighRes);
      // Calculate new width to maintain aspect ratio
      newWidth = Math.round((metadata.width / metadata.height) * newHeight);
      // Ensure the long side does not exceed the maximum allowed
      if (newWidth > maxLongSideHighRes) {
        newWidth = maxLongSideHighRes;
        newHeight = Math.round((metadata.height / metadata.width) * newWidth);
      }
    }

    resizeOptions.width = newWidth;
    resizeOptions.height = newHeight;
  } else {
    throw new Error('Invalid resolution parameter');
  }

  const resizedBuffer = await sharp(inputBuffer).rotate().resize(resizeOptions).toBuffer();

  const resizedMetadata = await sharp(resizedBuffer).metadata();
  return {
    buffer: resizedBuffer,
    bytes: resizedMetadata.size,
    width: resizedMetadata.width,
    height: resizedMetadata.height,
  };
}

/**
 * Resizes an image buffer to a specified format and width.
 *
 * @param {Object} options - The options for resizing and converting the image.
 * @param {Buffer} options.inputBuffer - The buffer of the image to be resized.
 * @param {string} options.desiredFormat - The desired output format of the image.
 * @param {number} [options.width=150] - The desired width of the image. Defaults to 150 pixels.
 * @returns {Promise<{ buffer: Buffer, width: number, height: number, bytes: number }>} An object containing the resized image buffer, its size, and dimensions.
 * @throws Will throw an error if the resolution or format parameters are invalid.
 */
async function resizeAndConvert({ inputBuffer, desiredFormat, width = 150 }) {
  const resizedBuffer = await sharp(inputBuffer)
    .resize({ width })
    .toFormat(desiredFormat)
    .toBuffer();
  const resizedMetadata = await sharp(resizedBuffer).metadata();
  return {
    buffer: resizedBuffer,
    width: resizedMetadata.width,
    height: resizedMetadata.height,
    bytes: Buffer.byteLength(resizedBuffer),
  };
}

module.exports = { resizeImageBuffer, resizeAndConvert };
