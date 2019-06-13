classdef (Abstract) stationary < matter.manips.volume
    % a stationary volume manipulator changes the volume by fixed values
    % not flows. Different from the substance manipulator the seperation
    % into stationary and flow manips for volumes has nothing to do with
    % flow phases but is purely used to describe manipulators which
    % describe volume change rates (flow) or change the volume by fixed
    % values (stationary)
    
    properties (SetAccess = private, GetAccess = public)
        % A function handle which contains the private function setProperty
        % of phase.m with fVolume as property which can be set
        hSetVolume
        
        % A function handle which contains the private function setProperty
        % of phase.m with fPressure as property which can be set
        hSetPressure
    end
    
    methods
        function this = stationary(sName, oPhase, sRequiredType)
            if nargin < 3, sRequiredType = []; end
            
            this@matter.manips.volume(sName, oPhase, sRequiredType);
            
            % create the function handles required to set the volume and
            % pressure properties of the connected phase
            this.hSetVolume     = this.oPhase.bindSetProperty('fVolume');
            this.hSetPressure   = this.oPhase.bindSetProperty('fPressure');
            
        end
        
        function update(this, fVolume, fPressure)
            % This update function can be overloaded by the derived
            % children, which can then access this function to set the
            % volume and pressure by using 
            % update@matter.manips.volume.stationary(fVolume, fPressure);
            this.hSetVolume(fVolume);
            this.hSetPressure(fPressure);
        end
        
        function detachManip(this)
            % Since the stationary volume manipulator additionally has
            % function handles specific for the phase to which it is
            % connected we must overload the detachManip function of
            % matter.manips with this function. The original function is
            % still executed, as all of these operations are necessary as
            % well but additionally the handles in the properties
            % hSetVolume and hSetPressure are set to empty here
            detachManip@matter.manips();
            
            this.hSetVolume     = [];
            this.hSetPressure   = [];
        end
            
        function reattachManip(this, oPhase)
            % Since the stationary volume manipulator additionally has
            % function handles specific for the phase to which it is
            % connected we must overload the attachManip function of
            % matter.manips with this function. The original function is
            % still executed, as all of these operations are necessary as
            % well but additionally the handles in the properties
            % hSetVolume and hSetPressure are set to the new phase
            reattachManip@matter.manips(oPhase);
            
            this.hSetVolume     = this.oPhase.bindSetProperty('fVolume');
            this.hSetPressure   = this.oPhase.bindSetProperty('fPressure');
        end
    end
end