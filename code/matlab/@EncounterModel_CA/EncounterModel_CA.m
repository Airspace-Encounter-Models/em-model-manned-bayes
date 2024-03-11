classdef EncounterModel_CA < handle & EncounterModel
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % Copyright 2023 Carleton Univerity and National Research Council of
    % Canada
    % SPDX-License-Identifier: BSD-2-Clause
   
    %% Constructor Function and Helpers
    methods

        function self = EncounterModel_CA(varargin)
            % EncounterModel_CA Instantiates an object by reading in an encounter model parameters from mat file
            %
            % SEE ALSO em_read_CAN

            self.isAutoUpdate = false;

            % Input handling
            p = inputParser;
            addParameter(p, 'parameters_filename', '');
            addParameter(p, 'idxZeroBoundaries', []);
            addParameter(p, 'isOverwriteZeroBoundaries', false);
            addParameter(p, 'labels_initial', {});
            addParameter(p, 'labels_transition', {});
            addParameter(p, 'temporal_map', nan(0, 2));
            addParameter(p, 'G_initial', false(0, 0));
            addParameter(p, 'G_transition', false(0, 0));
            addParameter(p, 'cutpoints_initial', {});
            addParameter(p, 'bounds_initial', nan(0, 2));
            addParameter(p, 'zero_bins', {});
            parse(p, varargin{:});

            % Either load parameters from file or inputParser
            parameters_filename = p.Results.parameters_filename;
            if ~isempty(p.Results.parameters_filename)
                idxZeroBoundaries = p.Results.idxZeroBoundaries;
                isOverwriteZeroBoundaries = p.Results.isOverwriteZeroBoundaries;

                % Load parameters from Canadian data
                parms = em_read_CAN(parameters_filename);
           
            else
                % Set parms based on inputParser
                parms = p.Results;

                % Remove default fields
                for ii = p.UsingDefaults
                    parms = rmfield(parms, ii);
                end
            end

            % Get fieldnames for parms
            fieldsIn = fieldnames(parms);

            % Get meta.class and property list of object
            % https://www.mathworks.com/help/matlab/matlab_oop/getting-information-about-properties.html
            mc = ?EncounterModel_CA;
            propertyList = mc.PropertyList';

            % Iterate over fields and assign if there is a match
            if ~isempty(fieldsIn)
                for ii = propertyList
                    % Check if dependent (can't set these manuall)
                    if ~ii.Dependent
                        isMatch = strcmpi(fieldsIn, ii.Name);
                        if any(isMatch)
                            self.(ii.Name) = parms.(ii.Name);
                        end
                    end
                end
            end

            % Preallocate N_initial if empty
   
            if isempty(self.N_initial)
                self.preallocNInitial;
            end

            % Preallocate start cell array for sampling
            self.preallocStart;

            % create priors
            self.updateDirichletInitial;
            self.updateDirichletTransition;

            self.isAutoUpdate = true;

        end % End constructor

    end % End methods


    %% Setters, Updaters, and Preallocate
    methods

       
        function setParameters(self, N_initial, N_transition, all_repeat, all_change)
            self.N_initial = N_initial;
            self.N_transition = N_transition;
            self.all_repeat = all_repeat;
            self.all_change = all_change;
        end

    end

      
end % End class def
