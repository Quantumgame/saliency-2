if ("imager" %in% installed.packages() == FALSE) {
  install.packages("imager")
}
library(imager)
library(tools)
source("featurePyramids.R")
source("gaussianPyramid.R")
source("imageProcessing.R")
source("utils.R")
source("normalization.R")
source("featureMaps.R")

makeSaliencyMap <- function(path, save_output = TRUE, verbose = FALSE) {
  image <- load.image(path)
  if (dim(image)[4] != 3) {
    stop("Image must be true color!")
  }
  
  # 3 rodzaje piramid - intensity, color, orientation
  # Konieczne do obliczenia feature map dla intensity, color, orientation
  color_RG_maps_pyramid <- makeRedGreenPyramid(image)
  color_BY_maps_pyramid <- makeBlueYellowPyramid(image)
  
  intensity_maps_pyramid <- makeIntensityPyramid(image)
  
  orientation_0_maps_pyramid <- makeOrientationPyramid(intensity_maps_pyramid, 0)
  orientation_45_maps_pyramid <- makeOrientationPyramid(intensity_maps_pyramid, 45)
  orientation_90_maps_pyramid <- makeOrientationPyramid(intensity_maps_pyramid, 90)
  orientation_135_maps_pyramid <- makeOrientationPyramid(intensity_maps_pyramid, 135)
  
  # Tworzenie feature maps, z których powstaną conspicuity maps
  # Feature map ma 6 poziomów
  color_RG_feature_maps <- maxNormalize(centerSurround(color_RG_maps_pyramid), c(0, 10))
  color_BY_feature_maps <- maxNormalize(centerSurround(color_BY_maps_pyramid), c(0, 10))
  
  intensity_feature_maps <- maxNormalize(centerSurround(intensity_maps_pyramid), c(0, 10))
  
  orientation_0_feature_maps <- maxNormalize(centerSurround(orientation_0_maps_pyramid), c(0, 10))
  orientation_45_feature_maps <- maxNormalize(centerSurround(orientation_45_maps_pyramid), c(0, 10))
  orientation_90_feature_maps <- maxNormalize(centerSurround(orientation_90_maps_pyramid), c(0, 10))
  orientation_135_feature_maps <- maxNormalize(centerSurround(orientation_135_maps_pyramid), c(0, 10))
  
  # Tworzenie conspicuity maps
  color_RG_combined_map <- maxNormalize(combineMaps(color_RG_feature_maps), c(0, 0))
  color_BY_combined_map <- maxNormalize(combineMaps(color_BY_feature_maps), c(0, 0))
  intensity_combined_map <- maxNormalize(combineMaps(intensity_feature_maps), c(0, 0))
  orientation_0_combined_map <- maxNormalize(combineMaps(orientation_0_feature_maps), c(0, 0))
  orientation_45_combined_map <- maxNormalize(combineMaps(orientation_45_feature_maps), c(0, 0))
  orientation_90_combined_map <- maxNormalize(combineMaps(orientation_90_feature_maps), c(0, 0))
  orientation_135_combined_map <- maxNormalize(combineMaps(orientation_135_feature_maps), c(0, 0))
  
  color_conspicuity_map <- maxNormalize(combineMaps(list(color_RG_combined_map, color_BY_combined_map)), c(0, 0)) / 6
  intensity_conspicuity_map <- intensity_combined_map / 3
  orientation_conspicuity_map <- maxNormalize(combineMaps(list(orientation_0_combined_map, orientation_45_combined_map, orientation_90_combined_map, orientation_135_combined_map)), c(0, 0)) / 12
  
  # Tworzenie silency map
  saliency_map <- maxNormalize(combineMaps(list(
    color_conspicuity_map,
    intensity_conspicuity_map,
    orientation_conspicuity_map)), c(0, 2))
  imager_saliency_map <- imrotate(as.cimg(saliency_map[,ncol(saliency_map):1]), 90)
  
  imager_modified_saliency <- imresize(im = imager_saliency_map, scale = nrow(image) / nrow(imager_saliency_map))
  imager_modified_saliency <- max(imager_modified_saliency) - imager_modified_saliency
  
  original_with_saliency <- registerSaliencyMap(image, imager_modified_saliency)
  
  if (verbose) {
    plot(imager_saliency_map, main = 'Saliency map')
    plot(imager_modified_saliency, main = 'Saliency map in original size (negative)')
    plot(image, main = 'Original image')
    plot(original_with_saliency, main = 'Original image with darkened salient locations')
  }
  if (save_output) {
    out_path <- file.path(dirname(path), paste("output", basename(file_path_sans_ext(path)), sep = "_"))
    dir.create(out_path)
    save.image(imager_saliency_map, paste(out_path, "small_saliency_map_neg.jpg", sep = "/"), quality = 1)
    save.image(imager_modified_saliency, paste(out_path, "full_saliency_map.jpg", sep = "/"), quality = 1)
    save.image(image, paste(out_path, "original_image.jpg", sep = "/"), quality = 1)
    save.image(original_with_saliency, paste(out_path, "image_with_salient_areas.jpg", sep = "/"), quality = 1)
  }
  original_with_saliency <- imrotate(original_with_saliency, -90)
  out_array <- array(0, c(nrow(original_with_saliency), ncol(original_with_saliency), 3))
  out_array[,,1] <- matrix(original_with_saliency[,,1,1], nrow = nrow(original_with_saliency), byrow = FALSE)
  out_array[,,2] <- matrix(original_with_saliency[,,1,2], nrow = nrow(original_with_saliency), byrow = FALSE)
  out_array[,,3] <- matrix(original_with_saliency[,,1,3], nrow = nrow(original_with_saliency), byrow = FALSE)
  return(list(matrix(imager_modified_saliency, nrow = ncol(imager_modified_saliency), byrow = TRUE),
              out_array))
}

