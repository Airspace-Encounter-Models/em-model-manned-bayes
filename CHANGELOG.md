# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project should adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `.gitattributes` to manage end of lines and git settings

### Changed

- Updated `UncorEncounterModel` and dependent functions to support most unconventional models and the due regard model. Functionality requested by and partly tested by @Wh0DKnee
- Improved documentation and instructions in `RUN_uncor` script
- Check for MATLAB version in `startup_bayes` and mapping toolbox in `UncorEncounterModel` constructor. These updates are in response to when creating geodetic tracks with `UncorEncounterModel/track`, as `readgeoraster` is called as within `msl2agl`.  `readgeoraster` was introduced as part of the MATLAB mapping toolbox in 2020a.
- Style fixes for entire repository using [MH Style from MISS_HIT](https://misshit.org/). Specifically used the following code in the root directory for this repository: `mh_style . --fix`
- Updated some variable names and replaced use of `obj` with `self` in objects to align better with the [PEP-8 style guide](https://www.python.org/dev/peps/pep-0008). Due to other repositories' dependency on `em-model-manned-bayes`, it is nontrivial to fully update `em-model-manned-bayes` to be analogously PEP-8 compliant.
- Updated and streamlined unconventional model parameter files based on MIT Lincoln Laboratory Report ATC-348
- Updated and renamed due regard model parameter file to use naming convention as the parameter files and based on MIT Lincoln Laboratory Report ATC-397
- Update .gitattributes to enforce `eol=LF` for .txt files

### Removed

- Property validation functions no longer use `mustBeVector`, which was introduced in 2020b and limits tech transfer
- Removed unconventional models with v1p2 suffix

### Fixed

- Fixed bug in `CorTerminalModel/createEncounter` where incorrect trajectory model was assigned
- Updates `dbn_sample` to use previous implementation if a dynamic variable depends on another dynamic variable. In release [1.4.0] `dbn_sample` was updated to calculate the index, `j`, upfront because `asub2ind` can introduce unwanted overhead and also preallocated events as a NaN array. In this previous release, the `for ii = order_transition` loop was added to identify the relationship between dynamic variables and its parents. Notably in the for `ii = order_transition` loop, the variable `x` was not updated. Now this is where the bug was introduced. If a dynamic variable was dependent on another dynamic variable (see unconventional glider model), `xj = x(parents)` would be equal for the element with the dynamic variable dependence. This would results in `asub2ind(rj, xj)` returning a negative value, which would create an error when indexing `N_transition{ii}(:, j(ii))`. Since the uncorrelated conventional models transition networks do not have any dynamic variables not dependent on another dynamic variable, this bug was not identified in release [1.4.0]. For this release, the bug was addressed by determining if any of the dynamic variables depend on another dynamic variable. This determines if we can calculate the index, `j`, upfront or via each iterate of `t`. If there is a dependence, it will sample the model similar to Release [1.3.0] where the events matrix was also preallocated as an empty array
- Update `UncorEncounterModel/getDynamicLimits` to check that variable indices (i.e. `idx_G`, `idx_A`, etc.) are not empty. Currently this check will only pass for model structures as the uncorrelated conventional aircraft models; the unconventional models currently all lack geographic domain (G) and will not pass this check. Without this check an error would throw when trying to use a logical operator on an empty variable.
- Update how `UncorEncounterModel/sample` calculates the order of variables when reorganizing the controls matrix. The model's temporal matrix is used explicitly instead of trying to infer the order from the controls matrix
- Update `UncorEncounterModel/sample` to ensure that the altitude minimum (`min_alt_ft`) and maximum (`max_alt_ft`) are not empty. They can be empty if the model structure does not have altitude layer, L, as a variable
- Fixed bug in `UncorEncounterModel` when dof.mat from em-core did not exist by checking if dot.mat actually exists
- Update `EncounterModel` getters for cutpoints_transition and bounds_transition to not assume a specific order of variables. Getters now create returned valued based on the model's label_initial
- README now instructs user to run startup script, `startup_bayes`. Bug first identified by @lydiaZeleke
- Update `bn_sample` to check that `ith` element in `start` is not empty (`~isempty`) nor a NaN (`~isnan`). Bug first identified and resolved by @hooveranna 

## [2.1.0] - 2021-10-01

### Added

- Classdef for `CorTerminalModel`
- `RUN_terminal` is an example RUN script demonstrating how to use the new `CorTerminalModel` class
- `aind2sub`, `discretize_bayes`, `hierarchical_discretize`, `setTransitionPriors` are various functions to help sample the Bayesian networks

### Changed

- `RUN_OOP` renamed to `RUN_uncor`
- Update primary `README.md` with information about the correlated terminal model and to better distinguish it from the RADES-based correlated extended model
- `UncorEncounterModel/track` sets minimum and maximum speed thresholds for rejection sampling based on the probability distribution of the speed bins, rather than the minimum and maximum speeds of the model structure. In release [2.0.0], the conventional uncorrelated models released in [1.3.0] had a maximum speed of 300 knots with a minimum speed of at least 30 knots for the fixed-wing models. The speed ranges for the different uncorrelated models are now the following:
  
| Aircraft Type | 1200-excluded | 1200-only |
| :-- | --- | --- |
| Fixed-Wing Multi-Engine | [120, 300] | [90, 300] |
| Fixed-Wing Single Engine | [60, 250] | [60, 250] |
| Rotorcraft | [30, 165] | [30, 165]

## [2.0.0] - 2021-10-01

### Added

- Classdef for `EncounterModel` superclass and `UncorEncounterModel` class
- `RUN_OOP` is an example RUN script demonstrating how to use the new `UncorEncounterModel` class
- `IdentifyGeographicVariable` to calculate the geographic domain variable, G

### Changed

- Update `EncounterModelEvents` with property validation functions
- Update `em_read` to calculate `bounds_initial` and `cutpoints_inital`
- Startup script add `em-core` to path
- Various functions updated to use `addParameter` instead of `addOptional` when using the MATLAB input parser
- `.gitignore` updated to ignore .png files in the output directory

### Fixed

- End of line whitespace in ASCII files for boundaries parameters had extra whitespace leading to incorrect reading of data by `em_read`. This bug was introduced in 1.4.0 and previous versions were note effected.

## [1.4.0] - 2021-07-19

### Added

- Correlated terminal encounter models based on terminal area radar or OpenSky Network processed tracks

### Changed

- Completely rewrote `em_read` so it no longer assumes a strict model structure with a specific set of model fields organized in a specific order
- Changed inputs to `em_sample`, `dbn_sample`, `dbn_hierarchical_sample` to be a struct of model parameters instead of individual parameters. This improves flexibility and readability
- `em_read` now calls `bn_sort` and calculates variable order for initial and transition networks. Calculating these upfront significantly improves performance because bn_sort was a bottleneck
- Reorganized `dbn_sample` to minimize repeat function calls and calculations
- `dbn_sample` now longer calls select_random because it was inefficiently adding overhead due to the multiple calls to `rand` and `cumsum`. This wasn't inefficient because `cumsum(weights)` don't change for the dynamic variables
- Since `allcomb` was added to em-core, `sample2track` now uses `allcomb` instead of `combvec`, which removes a dependency on the MATLAB Deep Learning Toolbox
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

## [1.2] - 2020-09-24

### Added

- Optional inputs to `em_read` to overwrite zero boundaries for a model

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

[2.1.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v2.1.0
[2.0.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v2.0.0
[1.4.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v1.4
[1.3.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v1.3
[1.2.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v1.2
[1.1.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v1.1
[1.0.0]: https://github.com/Airspace-Encounter-Models/em-model-manned-bayes/releases/tag/v1.0
