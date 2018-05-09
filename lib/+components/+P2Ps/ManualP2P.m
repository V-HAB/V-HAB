classdef ManualP2P < matter.procs.p2ps.flow
    % This p2p is designed to function like the manual solver for branches.
    % The user can use the setFlowRate function to specify the desired
    % partial mass flowrates (in kg/s) in an array (array has to be the
    % size of oMT.iSubstances with zeros for unused flowrates). For p2Ps
    % all flowrates have to be in the same direction, there is no check if
    % both a positive and a negative flowrate have been defined because
    % this would require calculation time, just do not do this ;)
    
    properties (SetAccess = protected, GetAccess = public)
        % parent system reference
        oParent;
        
        afFlowRates;
        
        fLastExec;
        
        bMassTransferActive = false;
        fMassTransferStartTime;
        fMassTransferTime;
        
    end
    
    methods
        function this = ManualP2P(oParent, oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);

            this.oParent = oParent;
        end
        
        function update(this, ~) 
            % Since the flowrate is set manually no update required, the
            % function still has to be here since it is called within V-HAB
            if this.bMassTransferActive && (this.fMassTransferStartTime + this.fMassTransferTime) < this.oTimer.fTime
                fTimeStep = (this.fMassTransferStartTime + this.fMassTransferTime) - this.oTimer.fTime;
                this.oIn.oPhase.oStore.setNextTimeStep(fTimeStep);
            end
            
            if this.bMassTransferActive && (this.fMassTransferStartTime + this.fMassTransferTime) >= this.oTimer.fTime
                
                arPartialFlowRates = zeros(1,this.oMT.iSubstances);
                fFlowRate = 0;
                this.setMatterProperties(fFlowRate, arPartialFlowRates);
                this.bMassTransferActive = false;
            end
        end
        
        function setFlowRate(this, afPartialFlowRates)
            % transforms the specified flowrates into the overall flowrate
            % and the partial mass ratios.
            if this.bMassTransferActive
                warning('Currently a mass transfer is in progress')
            end
                
            this.afFlowRates = afPartialFlowRates;
            fFlowRate = sum(afPartialFlowRates);
            if fFlowRate == 0
                arPartialFlowRates = zeros(1,this.oMT.iSubstances);
            else
                arPartialFlowRates = afPartialFlowRates/fFlowRate;
            end
            
            % extract specified substance with desired flow rate
            this.setMatterProperties(fFlowRate, arPartialFlowRates);
        end
        
        function setMassTransfer(this, afPartialMasses, fTime)
            % This function sets a specific mass that is transferred within
            % a specific time. After the mass has been transferred the
            % flowrate is set to 0 again. If a new mass transfer is
            % initialized while another one is already taking place, a
            % warning is displayed and the original mass transfer is
            % finished. The required input for the transport is an afMass
            % vector with corresponding partial masses
            %
            % Inputs are:
            % afPartialMasses in [kg]
            % fTime in [s]
            if fTime == 0
                error(['Stop joking, nothing can happen instantly. Manual solver ', this.oBranch.sName, ' was provided 0 time to transfer mass']);
            end
            
            if this.bMassTransferActive
                warning('Currently a mass transfer is in progress')
            end
            
            this.bMassTransferActive = true;
            this.fMassTransferStartTime = this.oTimer.fTime;
            this.fMassTransferTime = fTime;
            
            % transforms the specified flowrates into the overall flowrate
            % and the partial mass ratios.
            this.afFlowRates = afPartialMasses ./ fTime;
            fFlowRate = sum(this.afFlowRates);
            if fFlowRate == 0
                arPartialFlowRates = zeros(1,this.oMT.iSubstances);
            else
                arPartialFlowRates = this.afFlowRates/fFlowRate;
            end
            
            this.oIn.oPhase.oStore.setNextTimeStep(fTime);
            
            % extract specified substance with desired flow rate
            this.setMatterProperties(fFlowRate, this.afFlowRates);
        end
    end
end