classdef (Abstract) stationary < matter.manips.substance
    % stationary manipulator which can be used in normal phases to
    % calculate mass transformations
    
    methods
        function this = stationary(sName, oPhase)
            %% stationary class constructor
            % creates a new stationary manipulator
            % Inputs:
            % sName:    Name for this manip
            % oPhase:   Phase object in which this manip is located
            this@matter.manips.substance(sName, oPhase);
            
            if this.oPhase.bFlow
                % Manips of this type are intended to be used in conjunction
                % with a flow phase which has no mass. If you want to use a
                % manip in a normal phase please use the stationary manip type!
                this.throw('manip', 'The stationary manip %s is located in a flow phase. For flow phases use flow manips!', this.sName);
            end
        end
    end
end