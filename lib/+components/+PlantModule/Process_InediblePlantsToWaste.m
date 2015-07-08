classdef Process_InediblePlantsToWaste < matter.manips.substance.flow
    
    % Short description:
    %  All inedible fluid biomass components will be transformed to H2O-matter 
    %  -The fluid inedible biomass components will be destructed therefore
    %   An equal amount of H2O-matter will be created.
    
    %  -The dry inedible biomass compononents will not be treated by this manipulator
    %   (And remain inside the HavrestInedible-phase, till extracted)
    
    properties (SetAccess = protected, GetAccess = public)
        fLastUpdate = 0;
    end
    
    
    methods
        function this = Process_InediblePlantsToWaste(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
        end
        
        function update(this)
           % splits up the components taken from the flowphase inside of
           % the algae phase so the algae grow and produce O2
           
            %Array with 1 row and #columns for every matter available
            %column. -> 1 x this.oPhase.oMT.iSpecies
            % It contains all particular masses of all matter available
            % inside the considered phase
                afFRs      = this.getTotalFlowRates();
            
            %Arrays for matter handling
                %Array for matter summation
                    afPartials = zeros(1, this.oPhase.oMT.iSubstances);
                %Array with 18 rows and columns for all available matter
                %form the matter table.
                    arPartials2 = zeros(18, this.oPhase.oMT.iSubstances);
                    
                % Reference for molecular mass of requested matter    
                    afMolMass  = this.oPhase.oMT.afMolMass;
                % Reference of position number inside matter table for requested matter
                    tiN2I      = this.oPhase.oMT.tiN2I;
                    
            % Array with considered matter - all inedible parts, dry and fluid, of available plants    
            aiSubstanceArray=[tiN2I.DrybeanInedibleFluid, ...
                tiN2I.DrybeanInedibleDry, ...
                tiN2I.LettuceInedibleFluid, ...
                tiN2I.LettuceInedibleDry, ...
                tiN2I.PeanutInedibleFluid, ...
                tiN2I.PeanutInedibleDry, ...
                tiN2I.RiceInedibleFluid, ...
                tiN2I.RiceInedibleDry, ...
                tiN2I.SoybeanInedibleFluid, ...
                tiN2I.SoybeanInedibleDry, ...
                tiN2I.SweetpotatoInedibleFluid, ...
                tiN2I.SweetpotatoInedibleDry, ...
                tiN2I.TomatoInedibleFluid, ...
                tiN2I.TomatoInedibleDry, ...
                tiN2I.WheatInedibleFluid, ...
                tiN2I.WheatInedibleDry, ...
                tiN2I.WhitepotatoInedibleFluid, ...
                tiN2I.WhitepotatoInedibleDry];
            
            %Processing every single matter stated in "SpeciesArray" separatly
            % The amount of matter that is destructed will create the same
            % amount of H2O-matter
            for i=1:1:18
                iSubstance = aiSubstanceArray(i);
                    %For the H2O transformation only the fluid inedible
                    %biomass of the particular plants is considered
                        if mod(i,2)==1             
                            arPartials2(i,tiN2I.H2O)=afFRs(iSubstance);
                             afPartials(iSubstance)=-afFRs(iSubstance);
                        end;
           
            end;
            
            %All H2O will be summated from the single plants contribution
                afPartials(tiN2I.H2O)=sum(arPartials2(:,tiN2I.H2O));
                
            fTimeStep = this.oPhase.oStore.oTimer.fTime - this.fLastUpdate;
            
            afPartialFlows = afPartials ./ fTimeStep;
            
            %Setting control variable for call frequency check
            this.fLastUpdate = this.oPhase.oStore.oTimer.fTime;
            
            %The amount of matter that should be destructed and should be created
            % is forwarded here
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
    
end