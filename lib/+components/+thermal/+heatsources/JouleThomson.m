classdef JouleThomson < thermal.heatsource
    % a JouleThomson can be used to model the heat
    % released/consumed by a pressure change using the Joule Thomson
    % coefficient. This heat source only works with "normal"
    % phases/capacities, not with flow or boundary types!
    
    methods
        
        function this = JouleThomson(sName)
            this@thermal.heatsource(sName, 0);
            this.sName  = sName;
            
        end
        
        function setCapacity(this, oCapacity)
            % overwrite the generic setCapacity function so that we can
            % bind a callback to the phase massupdate (since the heat
            % release follows a pressure change
            if isempty(this.oCapacity)
                this.oCapacity = oCapacity;
            else
                this.throw('setCapacity', 'Heatsource already has a capacity object');
            end
            
            % bin callpack to update this heat source after a massupdate in
            % the phase occured, because a massupdate is always triggered
            % if the in/outflows of a phase change. Therefore, this also
            % indicates a change in the pressure change rate of the phase
            oCapacity.oPhase.bind('massupdate_post',@(~)this.update());
        end
        
        function update(this,~)
            % Calculate the current heat flow based on the pressure change
            % in the phase
            
            oPhase = this.oCapacity.oPhase;
            % calculate the current joule thomson coefficient
            fJouleThomson = this.oCapacity.oMT.calculateJouleThomson(oPhase);
            
            if strcmp(oPhase.sType, 'gas')
                % see issue 91 in gitlab for a detailed discussion of this
                % feature: https://gitlab.lrz.de/steps/STEPS-base/issues/91
                %
                % Equation from
                % https://link.springer.com/book/10.1007/978-3-642-05098-5
                % page 462 and simplified for a (within one tick) constant
                % joule thomson coefficient is: delta T = JT * delta P. The
                % pressure difference for a phase is based on the current
                % mass change
                this.fHeatFlow = oPhase.fMassToPressure * oPhase.fCurrentTotalMassInOut * fJouleThomson;
            else
                error('calculation for non gases currently not implemented')
            end
        end
    end
end