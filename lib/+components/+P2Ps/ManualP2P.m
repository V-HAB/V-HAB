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
        
    end
    
    methods
        function this = ManualP2P(oParent, oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);

            this.oParent = oParent;
        end
        
        function update(~) 
            % Since the flowrate is set manually now update required, the
            % function still has to be here since it is called within V-HAB
        end
        
        function setFlowRate(this, afPartialFlowRates)
            % transforms the specified flowrates into the overall flowrate
            % and the partial mass ratios.
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
    end
end