classdef Crew_Respiratory_Simulator_CO2 < matter.procs.p2ps.flow
    
    % A phase manipulator to simulate the CO2 generation from resperation
    % by the crew. It simply removes all CO2 from the Process phase in the
    % lung store thus producing the equivilent amount of CO2 that is produce
    % from the consumed oxygen
    
    properties (SetAccess = public, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
    end
    
    methods
        function this = Crew_Respiratory_Simulator_CO2(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.CO2)   = 1;
            
        end
        
        function update(this)
            
            fFlowRate = this.oIn.oPhase.toManips.substance.fCO2_FlowRate;
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
end