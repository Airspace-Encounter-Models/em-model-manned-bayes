# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project should adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2021-07-19

### Added

- Correlated terminal encounter models based on terminal area radar or OpenSky Network processed tracks

### Changed

- Completely rewrote `em_read` so it no longer assumes a strict model structure with a specific set of model fields organized in a specific order
- Changed inputs to `em_sample`, `dbn_sample`, `dbn_hierarchical_sample` to be a struct of model parameters instead of individual parameters. This improves flexibility and readability.
- `em_read` now calls `bn_sort` and calculates variable order for initial and transition networks. Calculating these upfront significantly improves performance because bn_sort was a bottleneck.
- Reorganized `dbn_sample` to minimize repeat function calls and calculations
- `dbn_sample` now longer calls select_random because it was inefficiently adding overhead due to the multiple calls to rand and cumsum. This wasn't inefficient because `cumsum(weights)` don't change for the dynamic variables
- More documentation on the terminal encounter model

### Fixed

- `em_read` to use `strfind` instead of deprecated `findstr` when calculating the temporal map
- `em_read` searches for t+1 and t-1 labels when creating the temporal map

## [1.3.0] - 2021-03-02

### Changed

- Uncorrelated OpenSky Network-based models organized into 1200-code and 1200-excluded models
- Uncorrelated OpenSky Network-based models include a new geographic variable, G=5, for Canada 
- README discussess common categorical variables and introduces the correlated terminal encounter model
- MATLAB startup script adds path to matlab directory instead of the entire code directory
- Copyright year updated to end in 2021

### Fixed

- Grammar in README

## [1.2.0] - 2020-09-24

### Added

- Optional inputs to `em_read` to overwrite zero bounadries for a model

### Changed

- License changed to the more permissive BSD-2 license.

## [1.1.0] - 2020-08-05

### Added

- Uncorrelated models trained using processed data curated from the OpenSky Network
- SPDX headers

### Changed

- Improved documentation

## [1.0.0] - 2020-05-14

### Added

- Initial public release

[1.3.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v1.3
[1.2.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v1.2
[1.1.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v1.1
[1.0.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v1.0
