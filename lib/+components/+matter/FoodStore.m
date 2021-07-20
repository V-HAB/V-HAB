classdef FoodStore < matter.store
% Generic Store for food, includes the necessary exmes and functions to
% supply humans with food and receive food

    properties (SetAccess = protected, GetAccess = public)
        
        iHumans = 0;
        
        iInputs = 0;
        
        oParent;
    end
    
    methods
        function this = FoodStore(oParentSys, sName, fVolume, tfFood)
            % Creating a store based on the volume. Added 1 m³ to the
            % volume for the human interface phases
            this@matter.store(oParentSys, sName, fVolume + 1);
            
            matter.phases.mixture(this, 'Food', 'solid', tfFood, this.oMT.Standard.Temperature, this.oMT.Standard.Pressure);
            
            this.oParent = oParentSys;
        end
        
        function requestFood = registerHuman(this, sPort)
            
            this.iHumans = this.iHumans + 1;
            
            oPhase = matter.phases.flow.mixture(this, ['Food_Output_', num2str(this.iHumans)], 'solid', [], this.oMT.Standard.Temperature, this.oMT.Standard.Pressure);
            
            matter.procs.exmes.mixture(this.toPhases.Food,     ['FoodPrepOut_', num2str(this.iHumans)]);
            matter.procs.exmes.mixture(oPhase,     ['FoodPrepIn_', num2str(this.iHumans)]);
            
            components.matter.P2Ps.ManualP2P(this, ['FoodPrepP2P_', num2str(this.iHumans)], ['Food.FoodPrepOut_', num2str(this.iHumans)], ['Food_Output_', num2str(this.iHumans), '.FoodPrepIn_', num2str(this.iHumans)]);
            
            matter.procs.exmes.mixture(oPhase,     ['Outlet_', num2str(this.iHumans)]);
            
            matter.branch(this.oParent, sPort, {}, [this.sName, '.Outlet_', num2str(this.iHumans)] , ['Food_Out_', num2str(this.iHumans)]);
            
            iHuman = this.iHumans;
            requestFood   = @(varargin) this.requestFood(iHuman, varargin{:});
        end
        
        function sInputExme = registerInput(this,~)
            this.iInputs = this.iInputs + 1;
            matter.procs.exmes.mixture(this.toPhases.Food,     ['FoodIn_', num2str(this.iInputs)]);
            
            sInputExme = ['FoodIn_', num2str(this.iInputs)];
        end
        
        function afPartialMasses = requestFood(this, iHuman, fEnergy, fTime, arComposition)
            %% requestFood
            % This function can be used to request food from the food store
            % for the human. The required function to perform this for the
            % corresponding human is provided as output upon using
            % registerHuman to bind a human to the food store. Through this
            % the iHuman parameter is already defined and the user only has
            % to provide the following inputs:
            % fEnergy:      The total energy the humans requires in J
            % fTime:        The time over which the human consumes this
            %               meal in s
            %
            % Optional Inputs:
            % In addition the user can specify the composition of the food
            % instead of using the current composition of the food store
            % arComposition: A vector with oMT.iSubstances entries which
            %                provides the desired mass ratio composition
            %                for the meal
            oP2P = this.toProcsP2P.(['FoodPrepP2P_', num2str(iHuman)]);
            
            % calculate mass transfer for the P2P
            if nargin > 4
                % In this case we only calculate the energy value for
                % the specified composition and with the composition
                % provided. To do so, we first have to split up the food
                % mass into its components to be able to calculate the
                % nutritional value
                afResolvedFoodMass = this.oMT.resolveCompoundMass(arComposition, this.toPhases.Food.arCompoundMass);
                
                % by multiplying the afNutritionalEnergy vector (which is
                % in J/kg for the desired food stuffs) with the
                % afResolvedFoodMass vector and summing it up we receive
                % the nutritional energy in J/kg for the desired food
                % composition (the result is in J/kg since we used the
                % composition vector, which sums up to one, and therefore
                % the total mass of afResolvedFoodMass is 1 kg, by then
                % multiplying each component with the nutritional energy of
                % the component, we get the total nutritional energy for 1
                % kg)
                fNutritionalEnergy = sum(afResolvedFoodMass .* this.oMT.afNutritionalEnergy);

                % Now we simply calculate the total mass required by
                % dividing the required energy with this value
                fMassToTransfer = fEnergy / fNutritionalEnergy;

                afPartialMasses = arComposition .* fMassToTransfer;
                
                abLimitedFoodSupply = this.toPhases.Food.afMass < afPartialMasses;
                if any(abLimitedFoodSupply)
                    
                    csLimitedFood = this.oMT.csI2N(abLimitedFoodSupply);
                    for iLimitedFood = 1:length(csLimitedFood)
                        fFoodRequested = afPartialMasses(this.oMT.tiN2I.(csLimitedFood{iLimitedFood}));
                        fFoodAvailable = this.toPhases.Food.afMass(this.oMT.tiN2I.(csLimitedFood{iLimitedFood}));
                        disp(['A Human is going hungry because ', num2str(fFoodRequested), ' kg of ', csLimitedFood{iLimitedFood}, ' were requested but only ', num2str(fFoodAvailable), ' kg of it were available'])
                    end
                    
                    afPartialMasses(abLimitedFoodSupply) = this.toPhases.Food.afMass(abLimitedFoodSupply);
                end
                
            else
                afResolvedMass = this.oMT.resolveCompoundMass(this.toPhases.Food.afMass, this.toPhases.Food.arCompoundMass);

                afNutritionalEnergy = afResolvedMass .* this.oMT.afNutritionalEnergy;
                fNutritionalEnergy = sum(afNutritionalEnergy);

                afPartialMasses = this.toPhases.Food.arPartialMass .* ((this.toPhases.Food.fMass /fNutritionalEnergy) * fEnergy);
            end
                
            if fNutritionalEnergy == 0
                afPartialMasses = zeros(1, this.oMT.iSubstances);
                disp(['A Human is going hungry because there is nothing edible left in store ', this.sName])
            end
            % Check if sufficient food of the demanded composition is
            % available
            oP2P.setMassTransfer(afPartialMasses, fTime);
        end
    end
end