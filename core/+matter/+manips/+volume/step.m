classdef (Abstract) step < matter.manips.volume
    % a stationary volume manipulator changes the volume by fixed values
    % not flows. Different from the substance manipulator the seperation
    % into stationary and flow manips for volumes has nothing to do with
    % flow phases but is purely used to describe manipulators which
    % describe volume change rates (flow) or change the volume by fixed
    % values (stationary)
    
    % to easier discern between volume manipulators that provide change
    % rates and volume manipulators that directly change the volume a
    % boolean flag is introduced to identify these two options. Since the
    % type is defined by inherting from this parent class, the property is
    % constant and cannot be changed.
    properties (Constant)
        % Identifies this manipualtor as a stationary volume manipulator
        bStepVolumeProcessor = true;
    end
    
    methods
        function this = step(sName, oPhase, sRequiredType)
            %% step class constructor
            % creates a step volume manipulator which changes the volume of
            % the phase by fixed values.
            %
            % Inputs:
            % sName:    Name for this manip
            % oPhase:   Phase object in which this manip is located
            %
            % Optional Input:
            % sRequiredType:    If the manip is only usable by a specific
            %                   type of phase, this can be specified using
            %                   this input parameter (e.g. 'gas' or
            %                   'liquid'
            if nargin < 3, sRequiredType = []; end
            
            this@matter.manips.volume(sName, oPhase, sRequiredType);
        end
    end
end