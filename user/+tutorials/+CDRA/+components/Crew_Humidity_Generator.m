classdef Crew_Humidity_Generator < matter.procs.p2ps.flow
    
    %A phase manipulator to simulate the humidity generation by the crew.
    %Should be used in the store where the crew is present and a liquid
    %water phase in the same store is necessary from which the water is
    %taken
    %                                
    %set access is public so that other parts of a V-HAB programm can set
    %the number of crew members (like if someone goes on an EVA) and the
    %humidity production (if one crew member is sweating the humidity
    %production per crewmember would have to be increased)
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
        function this = Crew_Humidity_Generator(oStore, sName, sPhaseIn, sPhaseOut, mbCrewMembers, oSystem)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.mbCrewMembers = mbCrewMembers;
            this.oSystem = oSystem;
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.H2O)   = 1;
            
        end
        
        function update(this)
            
            iCrewMembers = sum(this.mbCrewMembers);
            iIndexCM = find(this.mbCrewMembers);
            
            mfWaterVapor = zeros(iCrewMembers,1);
            mfSweat = zeros(iCrewMembers,1);
            %Only gets the values for the crew members that are simulated
            %by this proc as specified by mbCrewMembers
            for k = 1:iCrewMembers
                mfWaterVapor(k) = this.oSystem.tHumanMetabolicValues.(this.oSystem.cCrewState{iIndexCM(k)}).fWaterVapor;
                mfSweat(k) = this.oSystem.tHumanMetabolicValues.(this.oSystem.cCrewState{iIndexCM(k)}).fSweat;
            end
            
            %assumes that all of the sweat is already turned into water
            %vapor
            fFlowRate = sum(mfWaterVapor)+sum(mfSweat);
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
        function setCrew(this, mbCrewMembers)
            this.mbCrewMembers = mbCrewMembers;
        end
    end
end