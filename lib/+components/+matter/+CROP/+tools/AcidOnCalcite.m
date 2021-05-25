classdef AcidOnCalcite < matter.manips.substance.stationary
   
    properties
        
        % Current pH value of the BioPhase, which is assumed to be the pH
        %value of the TankSolution phase
        fCurrentpH;
        
        % Current volume of the TankSolution phase
        fVolume;
       
        % coefficients of the 10th degree polynomial, used to calculate
        % calcium dissolution out of calcite depending on the pH value
        afPolynomialCoeff = zeros(1, 11);
        
        % calculated calcium concentration in the TankSolution after acidic dissolution in mg/L
        fCalculatedCaConcentration;
        
        % calculated number of moles of calcium in the TankSolution after acidic dissolution
        fCalculatedMolesCalcium;
        
        % current number of moles of carbonate in the TankSolution after acidic dissolution
        fCalculatedMolesCarbonate;
        
        % calculated carbonate concentration in the TankSolution after acidic dissolution in mg/L
        fCalculatedCO3Concentration;
        
        % calculated mass of carbonate in the TankSolution after acidic dissolution in kg
        fCalculatedMassCarbonate;
        
        % Mass difference between calculated carbonate mass and current
        % carbonate mass in the TankSolution
        fCarbonateMassDifference;
        
        % number of moles corresponding to fCarbonateMassDifference
        fMolesDifference;
        
        oTankSolution;
        opH_Manip;
        
        fStep = 20;
    end
    
    methods
        function this = AcidOnCalcite(sName, oPhase)
            this@matter.manips.substance.stationary(sName, oPhase);
            
           % Load the coefficients of the 10th degree polynomial, which was
           % used to fit the curve from Sebastian Teir et al.: "Stability of
           % calcium carbonate and magnesium carbonate in rainwater and nitric 
           % acid solutions", 2006, [] in the thesis. The curve depicts the
           % dissolution of calcium in acidic water depending on the pH value
           sFullpath = mfilename('fullpath');
           [sFile,~,~] = fileparts(sFullpath);
           tfPolynomialData = load([sFile '\+pHCurve\fit.mat']);
           afPolynomialCoeff = tfPolynomialData.fit.coeff;
           
           this.afPolynomialCoeff = afPolynomialCoeff;
 
           this.oTankSolution = this.oPhase.oStore.oContainer.toStores.CROP_Tank.toPhases.TankSolution;
           this.opH_Manip = this.oPhase.oStore.oContainer.toStores.CROP_Tank.toPhases.Aeration.toManips.substance;
           
           this.fStep = this.oPhase.oStore.oContainer.fTimeStep;
        end
    end
     
    methods (Access = protected)
        function update(this)
            
            if ~this.oPhase.oStore.oContainer.bResetInitialMass && this.oPhase.afMass(this.oMT.tiN2I.CaCO3) > 0
                
                % get current pH value
                this.fCurrentpH = this.opH_Manip.fpH;
                fpH = this.fCurrentpH;

                % get current volume of the TankSolution phase
                this.fVolume = this.oTankSolution.fVolume;

                % calculate Ca concentration in TankSolution after acidic dissolution of calcite in mg/L
                fTemporaryResult = 0;
                for i = 1:11
                    fTemporaryResult = fTemporaryResult + (this.afPolynomialCoeff(12-i) * fpH^(i-1));
                end

                if fTemporaryResult <= 0
                    % No additional caclite should dessolve in this case:
                    afPartialFlowRates = zeros(1, this.oMT.iSubstances);
                    update@matter.manips.substance.stationary(this, afPartialFlowRates);
                    this.oPhase.oStore.toProcsP2P.Calcite_to_TankSolution.setFlowRate(afPartialFlowRates);
                    
                    return
                else
                    % Previous calculation led to too low carbon
                    % concentrations and pH values, therefore adjusted the
                    % calculation since the plot usded to derive this is
                    % actually also not very well suited to the high pH
                    % values
                    this.fCalculatedCaConcentration = fTemporaryResult;
                end

                % convert to corresponding number of moles
                this.fCalculatedMolesCalcium = (this.fCalculatedCaConcentration * 1000 * this.fVolume) / ...
                                     (1e6 * this.oMT.afMolarMass(this.oMT.tiN2I.Ca2plus));

                % the number of moles of calcium and carbonate dissociated from
                % calcite are equal
                this.fCalculatedMolesCarbonate = this.fCalculatedMolesCalcium;

                % calculate CO3 concentration in TankSolution after acidic dissolution of calcite in mg/L
                this.fCalculatedCO3Concentration = (this.fCalculatedMolesCarbonate * 1e6 *this.oMT.afMolarMass(this.oMT.tiN2I.CO3)) / ...
                                     (1000 * this.fVolume);

                % convert to corresponding mass in kg
                this.fCalculatedMassCarbonate = 1e-6 * this.fCalculatedCO3Concentration * 1000* this.fVolume;

                % compare with current mass, if smaller, do nothing, if bigger,
                % calculate difference. Add diference to the phase. Calculate
                % moles of difference. Add Ca and remove CaCO3 accordingly
                afPartialFlowRates = zeros(1, this.oMT.iSubstances);

                if this.oPhase.afMass(this.oMT.tiN2I.CO3) >= this.fCalculatedMassCarbonate
                    % if theoretical carbonate mass after acidic dissolution does not surpass
                    % the current carbonate mass in the TankSolution, no
                    % substance shall be added or removed
                    fpHManipCO3Flow = this.opH_Manip.afPartialFlows(this.oMT.tiN2I.CO3);
                    if fpHManipCO3Flow < 0
                        fCO3FlowRate = - fpHManipCO3Flow;
                    else
                        fCO3FlowRate = 0;
                    end
                else
                    % calculate the mass difference between the theoretical
                    % carbonate mass resulting from acidic dissolution and current
                    % carbonate mass in the Tanksolution
                    this.fCarbonateMassDifference = this.fCalculatedMassCarbonate - this.oTankSolution.afMass(this.oMT.tiN2I.CO3);

                    if this.fCarbonateMassDifference < 0
                        this.fCarbonateMassDifference = 0;
                    end
                    
                    % convert to number of moles, which is equal to the number
                    % of moles for calcium and calcite
                    this.fMolesDifference = this.fCarbonateMassDifference / this.oMT.afMolarMass(this.oMT.tiN2I.CO3);

                    if this.fMolesDifference < 0
                        this.fMolesDifference = 0;
                    end
                    
                    fpHManipCO3Flow = this.opH_Manip.afPartialFlows(this.oMT.tiN2I.CO3);
                    fCO3FlowRate = (this.fCarbonateMassDifference / this.fStep);
                    if fpHManipCO3Flow < 0
                        fCO3FlowRate = fCO3FlowRate - 1.3 * fpHManipCO3Flow;
                    end
                    
                end
                fCO3FlowRateMolar = fCO3FlowRate / this.oMT.afMolarMass(this.oMT.tiN2I.CO3);
                % adjust flow rates
                afPartialFlowRates(this.oMT.tiN2I.CO3)      =    fCO3FlowRate;
                afPartialFlowRates(this.oMT.tiN2I.Ca2plus)  =    fCO3FlowRateMolar * this.oMT.afMolarMass(this.oMT.tiN2I.Ca2plus);
                afPartialFlowRates(this.oMT.tiN2I.CaCO3)    = -  fCO3FlowRateMolar * this.oMT.afMolarMass(this.oMT.tiN2I.CaCO3);
            else
                afPartialFlowRates = zeros(1, this.oMT.iSubstances);
            end
            update@matter.manips.substance.stationary(this, afPartialFlowRates);
            
            afFlowRates = zeros(1, this.oMT.iSubstances);
            afFlowRates(this.oMT.tiN2I.Ca2plus)  = afPartialFlowRates(this.oMT.tiN2I.Ca2plus);
            afFlowRates(this.oMT.tiN2I.CO3) = afPartialFlowRates(this.oMT.tiN2I.CO3);
            this.oPhase.oStore.toProcsP2P.Calcite_to_TankSolution.setFlowRate(afFlowRates);
        end
    end
end