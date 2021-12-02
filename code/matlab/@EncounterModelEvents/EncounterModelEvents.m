classdef EncounterModelEvents < handle
    % Copyright 2018 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2
    % This class defines the encounter model events, which are times when a
    % change in the aircraft dynamics occurs
    %
    % EncounterModelEvents Properties:
    %   time_s - Time (seconds)
    %   verticalRate_fps - Vertical rate (feet per second)
    %   turnRate_radps - Turn rate (radians per second)
    %   longitudeAccel_ftpss - Longitudinal acceleration (feet per second squared)
    %   event - Event matrix of time, vertical rate, turn rate, and longitudinal acceleration
    %
    % EncounterModelEvents Methods:
    %   EncounterModelEvents - Constructor
    %   createEventMatrix - Creates an event matrix and saves it to file

    %% Properties
    properties (GetAccess = 'public', SetAccess = 'public')
        time_s(:, :) double {mustBeReal, mustBeFinite} = 0  % Time (seconds)
        verticalRate_fps(:, :) double {mustBeReal, mustBeFinite}  = 0  % Vertical rate (feet per second)
        turnRate_radps(:, :) double {mustBeReal, mustBeFinite}  = 0  % Turn rate (radians per second)
        longitudeAccel_ftpss(:, :) double {mustBeReal, mustBeFinite}  = 0  % Longitudinal acceleration (feet per second squared)
    end % end properties

    properties (Dependent = true)
        % The event matrix = [ time_s(:) verticalRate_fps(:) turnRate_radps(:) longitudeAccel_ftpss(:)]
        event(:, 4) double {mustBeReal, mustBeFinite}
    end

    %% Setters and Getters
    methods

        function self = set.event(self, eventMatrix)
            assert(size(eventMatrix, 2) == 4);
            self.time_s = eventMatrix(:, 1);
            self.verticalRate_fps = eventMatrix(:, 2);
            self.turnRate_radps = eventMatrix(:, 3);
            self.longitudeAccel_ftpss = eventMatrix(:, 4);
        end

        function eventMatrix = get.event(self)
            eventMatrix = [self.time_s(:) self.verticalRate_fps(:) self.turnRate_radps(:) self.longitudeAccel_ftpss(:)];
            % eventMatrix always needs to have at least one row
            if size(eventMatrix, 1) == 0
                eventMatrix = [0 0 0 0];
            end
        end

    end

    %% Constructor and Other Methods
    methods (Access = 'public')

        function self = EncounterModelEvents (varargin)
            % EncounterModelEvents Instantiates object

            % Parse Inputs
            p = inputParser;
            if any(strcmp(varargin, 'event'))
                addParamValue(p, 'event', [0 0 0 0]);
            else % If event matrix is being passed, ignore control individual properties
                addParamValue(p, 'time_s', self.time_s);
                addParamValue(p, 'verticalRate_fps', self.verticalRate_fps);
                addParamValue(p, 'turnRate_radps', self.turnRate_radps);
                addParamValue(p, 'longitudeAccel_ftpss', self.longitudeAccel_ftpss);
            end
            parse(p, varargin{:});

            % Set Properties
            fieldsSet = intersect(fieldnames(p.Results), fieldnames(self));
            for i = 1:1:numel(fieldsSet)
                self.(fieldsSet{i}) = p.Results.(fieldsSet{i});
            end

            % Error Checking
            assert(all((size(self.time_s) == size(self.verticalRate_fps)) == (size(self.turnRate_radps) == size(self.longitudeAccel_ftpss))), 'Sizes of time_s, verticalRate_fps, turnRate_radps, longitudeAccel_ftpss are not equal');
        end % End constructor

        function event = createEventMatrix(self, filename)
            % createEventMatrix Creates an event matrix and saves to a .mat
            % file

            assert(ischar(filename), 'Second input must be a char'); % Error checking
            event = self.event'; % Format according to how Logic and Response: Nominal Trajectory block is expecting
            save(filename, 'event'); % Save .mat file for block
        end

    end % End methods

end % End classdef
