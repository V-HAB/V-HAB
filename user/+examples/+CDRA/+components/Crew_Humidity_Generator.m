classdef Crew_Humidity_Generator < matter.procs.p2ps.stationary
    
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
        oSystem;
        
        % Defines which species are extracted
        arExtractPartials;
    end
    
    methods
        function this = Crew_Humidity_Generator(oStore, sName, sPhaseIn, sPhaseOut, oSystem)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.oSystem = oSystem;
            
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.H2O)   = 1;
            
        end
        
        function setCrew(this, mbCrewMembers)
            this.mbCrewMembers = mbCrewMembers;
        end
    end
        
    methods (Access = protected)
        function update(this)
            % According to ICES 2000-01-2345 12 lb of humidity per day were
            % constant over the test
            fFlowRate = 6.3*10^-5;
            
            % Set the new flow rate. If the second parameter (partial
            % masses to extract) is not provided, the partial masses from
            % the phase itself are used (i.e. extracting all species
            % equally).
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
        end
    end
end