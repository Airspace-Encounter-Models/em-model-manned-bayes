classdef EncounterModelEvents < handle
    % Copyright 2018 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2
    % This class defines the encounter model events, which are times when a
    % change in the aircraft dynamics occurs
    %% Properties
    properties (GetAccess = 'public', SetAccess = 'public')
        time_s(:,:) double {mustBeReal, mustBeFinite} = 0; % seconds
        verticalRate_fps(:,:) double {mustBeReal, mustBeFinite}  = 0; % feet per second
        turnRate_radps(:,:) double {mustBeReal, mustBeFinite}  = 0; % radians per second
        longitudeAccel_ftpss(:,:) double {mustBeReal, mustBeFinite}  = 0; % feet per second squared
    end % end properties
    
    properties (Dependent=true)
        % The event matrix = [ time_s(:) verticalRate_fps(:) turnRate_radps(:) longitudeAccel_ftpss(:)]
        event(:,4) double {mustBeReal, mustBeFinite}
    end
    
    %% Setters and Getters
    methods
        function obj = set.event( obj, eventMatrix )
            assert( size( eventMatrix,2 ) == 4 );
            obj.time_s = eventMatrix(:,1);
            obj.verticalRate_fps = eventMatrix(:,2);
            obj.turnRate_radps = eventMatrix(:,3);
            obj.longitudeAccel_ftpss = eventMatrix(:,4);
        end
        function eventMatrix = get.event( obj )
            eventMatrix = [obj.time_s(:) obj.verticalRate_fps(:) obj.turnRate_radps(:) obj.longitudeAccel_ftpss(:)];
            % eventMatrix always needs to have at least one row
            if( size( eventMatrix, 1 ) == 0 )
                eventMatrix = [ 0 0 0 0 ];
            end
        end
    end
    
    %% Constructor
    methods(Access = 'public')
        function obj = EncounterModelEvents (varargin)
            % Parse Inputs
            p = inputParser;
            if any(strcmp(varargin,'event'))
                addParamValue(p,'event',[0 0 0 0]);
            else % If event matrix is being passed, ignore control individual properties
                addParamValue(p,'time_s',obj.time_s);
                addParamValue(p,'verticalRate_fps',obj.verticalRate_fps);
                addParamValue(p,'turnRate_radps',obj.turnRate_radps);
                addParamValue(p,'longitudeAccel_ftpss',obj.longitudeAccel_ftpss);
            end
            parse(p,varargin{:});
            
            % Set Properties
            fieldsSet = intersect( fieldnames(p.Results), fieldnames(obj) );
            for i = 1:1:numel(fieldsSet)
                obj.(fieldsSet{i}) = p.Results.(fieldsSet{i});
            end
            
            % Error Checking
            assert(all((size(obj.time_s) == size(obj.verticalRate_fps)) == (size(obj.turnRate_radps) == size(obj.longitudeAccel_ftpss))),'Sizes of time_s, verticalRate_fps, turnRate_radps, longitudeAccel_ftpss are not equal');
        end % End constructor
        
        function event = createEventMatrix(obj,filename)
            assert(ischar(filename),'Second input must be a char'); % Error checking
            event = obj.event';% Format according to how Logic and Response: Nominal Trajectory block is expecting
            save(filename, 'event'); % Save .mat file for block
        end
        
    end % End methods
    
end %End classdef