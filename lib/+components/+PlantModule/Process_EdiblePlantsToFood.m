classdef Process_EdiblePlantsToFood < matter.manips.substance.flow
    
    % Short description:
    %  All edible biomass components will be transformed to food-matter
    %  -The amount of edible dry and edible fluid biomass components will
    %   be destructed therefore.
    %   An equal amount of food-matter is created
    
    properties (SetAccess = protected, GetAccess = public)
        fLastUpdate = 0;
    end
    
    
    methods
        function this = Process_EdiblePlantsToFood(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
        end
        
        function update(this)
           
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
                afMolMass  = this.oPhase.oMT.afMolarMass;
            % Reference of position number inside matter table for requested matter
                tiN2I      = this.oPhase.oMT.tiN2I;
            
            % Array with considered matter - all edible parts, dry and fluid, of available plants    
            aiSpeciesArray=[tiN2I.DrybeanEdibleFluid, ...
                tiN2I.DrybeanEdibleDry, ...
                tiN2I.LettuceEdibleFluid, ...
                tiN2I.LettuceEdibleDry, ...
                tiN2I.PeanutEdibleFluid, ...
                tiN2I.PeanutEdibleDry, ...
                tiN2I.RiceEdibleFluid, ...
                tiN2I.RiceEdibleDry, ...
                tiN2I.SoybeanEdibleFluid, ...
                tiN2I.SoybeanEdibleDry, ...
                tiN2I.SweetpotatoEdibleFluid, ...
                tiN2I.SweetpotatoEdibleDry, ...
                tiN2I.TomatoEdibleFluid, ...
                tiN2I.TomatoEdibleDry, ...
                tiN2I.WheatEdibleFluid, ...
                tiN2I.WheatEdibleDry, ...
                tiN2I.WhitepotatoEdibleFluid, ...
                tiN2I.WhitepotatoEdibleDry];
                
            %Processing every single matter stated in "SpeciesArray" separatly
            % The amount of matter that is destructed will create the same
            % amount of food-matter
            for i=1:1:18                
                iSubstance = aiSpeciesArray(i);
                
                %Matter that is destructed - particular plant components
                    afPartials(iSubstance)=-afFRs(iSubstance);
                %Matter that is created as food-matter
                    arPartials2(i,tiN2I.Food)=afFRs(iSubstance)/afMolMass(iSubstance)*afMolMass(tiN2I.Food);


            end;
            
            %All food will be summated from the single plants contribution
                afPartials(tiN2I.Food)=sum(arPartials2(:,tiN2I.Food)); 
                
            fTimeStep = this.oPhase.oStore.oTimer.fTime - this.fLastUpdate;
            
            afPartialFlows = afPartials ./ fTimeStep;
            
            %Setting control variable for call frequency check
            this.fLastUpdate = this.oPhase.oStore.oTimer.fTime;
            %The amount of matter that should be destructed and should be created
            % is be forwarded here
            update@matter.manips.substance.flow(this, afPartialFlows);
        end
    end
    
end