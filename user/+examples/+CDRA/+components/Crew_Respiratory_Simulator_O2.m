classdef Crew_Respiratory_Simulator_O2 < matter.procs.p2ps.stationary
    
    %A phase manipulator to simulate the CO2 generation from resperation
    %by the crew. Should be used in the store where the crew is present and
    %a gas phase in the same store represents (part) of the human
    %                                
    %set access is public so that other parts of a V-HAB programm can set
    %the number of crew members (like if someone goes on an EVA) and the
    %resperatory rates (if one crew member is working heavily etc)
    properties (SetAccess = public, GetAccess = public)
        %boolean arry to decide which crew member from the crew planer are 
        %simulated with this proc. The total number of CM simulated by this
        %proc is the sum over this variable (since every CM that is 
        %simulated is one an everything else is 0). The overall total
        %number of CM is the length of this vector.
        mbCrewMembers;  
        
        oSystem;
        
        % Defines which species are extracted
        arExtractPartials;
    end
    
    methods
        function this = Crew_Respiratory_Simulator_O2(oStore, sName, sPhaseIn, sPhaseOut, mbCrewMembers, oSystem)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.mbCrewMembers = mbCrewMembers;
            this.oSystem = oSystem;
        
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.O2)   = 1;
            
        end
        
        function setCrew(this, mbCrewMembers)
            this.mbCrewMembers = mbCrewMembers;
        end
    end
        
    methods (Access = protected)
        function update(this)
            
            iCrewMembers = sum(this.mbCrewMembers);
            iIndexCM = find(this.mbCrewMembers);
            
            mfO2Flow = zeros(iCrewMembers,1);
            for k = 1:iCrewMembers
                mfO2Flow(k) = this.oSystem.tHumanMetabolicValues.(this.oSystem.cCrewState{iIndexCM(k)}).fO2Consumption;
            end
            
            fFlowRate = sum(mfO2Flow);
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
end