classdef Crew_Respiratory_Simulator_CO2 < matter.procs.p2ps.stationary
    
    %A phase manipulator to simulate the CO2 generation from resperation
    %by the crew. Should be used in the store where the crew is present and
    %a gas phase in the same store represents (part) of the human
    %                                
    %set access is public so that other parts of a V-HAB programm can set
    %the number of crew members (like if someone goes on an EVA) and the
    %resperatory rates (if one crew member is working heavily etc)
    properties (SetAccess = public, GetAccess = public)
        %Number of Crewmembers
        mbCrewMembers;  
        
        oSystem;
        
        % Defines which species are extracted
        arExtractPartials;
    end
    
    methods
        function this = Crew_Respiratory_Simulator_CO2(oStore, sName, sPhaseIn, sPhaseOut, mbCrewMembers, oSystem)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.mbCrewMembers = mbCrewMembers;
            this.oSystem = oSystem;
        
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.CO2)   = 1;
            
        end
        function setCrew(this, mbCrewMembers)
            this.mbCrewMembers = mbCrewMembers;
        end
    end
        
    methods (Access = protected)
        function update(this)
            
            iCrewMembers = sum(this.mbCrewMembers);
            iIndexCM = find(this.mbCrewMembers);
            
            mfCO2Flow = zeros(iCrewMembers, 1);
            for k = 1:iCrewMembers
                mfCO2Flow(k) = this.oSystem.tHumanMetabolicValues.(this.oSystem.cCrewState{iIndexCM(k)}).fCO2Production;
            end
            
            fFlowRate = sum(mfCO2Flow);
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
end