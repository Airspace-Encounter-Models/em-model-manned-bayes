# MATLAB Code

## Run Scripts

### Classes

File | Description |
:--- | :--- |
[RUN_uncor.m](RUN_uncor.m) | Samples and creates tracks from an uncorrelated encounter model using the `UncorEncounterModel` class
[RUN_terminal.m](RUN_terminal.m) | Samples and creates encounters from the correlated terminal encounter model using the `CorTerminalModel` class

### Function specific

*The described functionality is expected to be removed in a future release*

Prior to the OOP classes, model sampling was was previously solely demonstrated using run script,[`RUN_1_emsample`](./code/matlab/RUN_1_emsample.m), which calls the function, [`em_sample`](./code/matlab/em_sample.m). The run script and function have been partly updated to use the `EncounterModel` superclass but still samples the method without using class methods. A followup run script, [`RUN_2_sample2track`](./code/matlab/RUN_2_sample2track.m), calls [`sample2track`](./code/matlab/sample2track.m) to generate basic (x,y,z) tracks for some of the model samples. Not all models are currently supported and only uncorrelated, glider (unconventional), and paraglider (unconventional), and HAA samples have been tested with the function.

File | Description |
:--- | :--- |
[RUN_1_emsample.m](RUN_1_emsample.m) | Samples an uncorrelated encounter model using `em_sample`
[RUN_2_sample2track.m](RUN_2_sample2track.m) | Using `sample2track`, output first-order (t,x,y,z) tracks in .csv files from `RUN_1_emsample.m`

## Functions

The following are the core functions, this is not a comprehensive list:

File | Description |
:--- | :--- |
[asub2ind.m](asub2ind.m) | Linear index from multiple subscripts.
[bn_sample.m](bn_sample.m) | Produces a sample from a Bayesian network.
[bn_sort.m](bn_sort.m) | Produces a topological sort of a Bayesian network.
[dbn_sample.m](dbn_sample.m) | Samples from a dynamic Bayesian network.
[em_read.m](em_read.m)  | Reads an encounter model parameters file.
[em_read_CAN.m](em_read_CAN.m)  | Reads a Canadian encounter model parameters file.
[em_sample.m](em_sample.m) | Outputs samples from an encounter model to files.
[IdentifyGeographicVariable](IdentifyGeographicVariable.m) | Identifies the geographic domain for latitude, longitude coordinates
[select_random.m](select_random.m) | Randomly selects an index according to specified weights.

## Distribution Statement

DISTRIBUTION STATEMENT A. Approved for public release. Distribution is unlimited.

© 2008-2021 Massachusetts Institute of Technology.

This material is based upon work supported by the Federal Aviation Administration (FAA) and the National Aeronautics and Space Administration (NASA) under Air Force Contract No. FA8702-15-D-0001. Any opinions, findings, conclusions or recommendations expressed in this material are those of the author(s) and do not necessarily reflect the views of the FAA or NASA.

Delivered to the U.S. Government with Unlimited Rights, as defined in DFARS Part 252.227-7013 or 7014 (Feb 2014). Notwithstanding any copyright notice, U.S. Government rights in this work are defined by DFARS 252.227-7013 or DFARS 252.227-7014 as detailed above. Use of this work other than as specifically authorized by the U.S. Government may violate any copyrights that exist in this work.

This document is derived from work done for the FAA (and possibly others), it is not the direct product of work done for the FAA. The information provided herein may include content supplied by third parties.  Although the data and information contained herein has been produced or processed from sources believed to be reliable, the Federal Aviation Administration makes no warranty, expressed or implied, regarding the accuracy, adequacy, completeness, legality, reliability or usefulness of any information, conclusions or recommendations provided herein. Distribution of the information contained herein does not constitute an endorsement or warranty of the data or information provided herein by the Federal Aviation Administration or the U.S. Department of Transportation.  Neither the Federal Aviation Administration nor the U.S. Department of Transportation shall be held liable for any improper or incorrect use of the information contained herein and assumes no responsibility for anyone’s use of the information. The Federal Aviation Administration and U.S. Department of Transportation shall not be liable for any claim for any loss, harm, or other damages arising from access to or use of data or information, including without limitation any direct, indirect, incidental, exemplary, special or consequential damages, even if advised of the possibility of such damages. The Federal Aviation Administration shall not be liable to anyone for any decision made or action taken, or not taken, in reliance on the information contained herein.
