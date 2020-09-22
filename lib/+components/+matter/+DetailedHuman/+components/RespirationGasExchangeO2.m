classdef RespirationGasExchangeO2 < matter.procs.p2ps.flow
    
    properties (SetAccess = protected, GetAccess = public)
        
        afFlowRates;
        
        oCO2_P2P;
    end
    properties (Constant)
        
        % TBD: Calculate this dynamically? Only makes sense if it is added
        % to the matter table. More information on this can be found in:
        % "The measurement of blood density and its meaning", T. Kenner,
        % 1989
        % https://link.springer.com/content/pdf/10.1007%2FBF01907921.pdf
        fBloodDensity = 1050;
        
        % Parameters according to "An integrated model of the human
        % ventilatory control system: the response to hypercapnia",
        % Ursino, M.; Magosso, E.; Avanzolini, G., 2001 
        % Table 1
        
        %% Saturation calculation parameters
        fBeta_1     =   0.008275;   %[mmHg^-1]
        fBeta_2     =   0.03255;    %[mmHg^-1]
        fAlpha_1    =   0.03198;    %[mmHg^-1]
        fAlpha_2    =   0.05591;    %[mmHg^-1]
        fK1         =   14.99;      %[mmHg]
        fK2         =   194.4;      %[mmHg]
        fC1         =   9;          %[mmol l^-1]
        fC2         =   86.11;      %[mmol l^-1]
        fa1         =   0.3836;
        fa2         =   1.819;
        %                            gas density at standard conditions * 
        fHenryConstantO2  = (3.17*10^-5 * 1.4290 * 1.059 * 760 / 101325); % [kg/(m^3 Pa)]
        fHenryConstantCO2 = (6.67*10^-4 * 1.9768 * 1.059 * 760 / 101325); % [kg/(m^3 Pa)]
    end
    
    methods
        function this = RespirationGasExchangeO2(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut, oCO2_P2P)
            % this P2P
            % sPhaseAndPortIn muste be the tissue phase!
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            
            this.oCO2_P2P = oCO2_P2P;
        end
        
        function calculateFlowRate(this, afInsideInFlowRate, aarInsideInPartials, afOutsideInFlowRate, aarOutsideInPartials)
            % The Inside is the air, while the outside is the blood in this
            % case:
            
            fGasPressure = this.oIn.oPhase.fPressure;
            if ~(isempty(afInsideInFlowRate) || all(sum(aarInsideInPartials) == 0))
                afPartialFlowsAir   = sum((afInsideInFlowRate .* aarInsideInPartials),1);
                afCurrentMolsIn     = (afPartialFlowsAir./ this.oMT.afMolarMass);
                arFractions         = afCurrentMolsIn ./ sum(afCurrentMolsIn);
                afPP                = arFractions .* fGasPressure; 
            else
                afPartialFlowsAir = zeros(1,this.oMT.iSubstances);
                afPP = zeros(1,this.oMT.iSubstances);
                % In case nothing flows we assume standard ISS air
                % composition because otherwise the calculated values will
                % result in inf and NaN values later on
                afPP(this.oMT.tiN2I.N2) = 8e4;
                afPP(this.oMT.tiN2I.O2) = 2.1e4;
                afPP(this.oMT.tiN2I.CO2) = 400;
            end
            
            if ~(isempty(afOutsideInFlowRate) || all(sum(aarOutsideInPartials) == 0))
                afPartialFlowsBlood = sum((afOutsideInFlowRate .* aarOutsideInPartials),1);
            else
                afPartialFlowsBlood = zeros(1,this.oMT.iSubstances);
            end
            
            fTotalFlowRateAir       = sum(afPartialFlowsAir);
            arMassRatiosAirFlow     = afPartialFlowsAir ./ fTotalFlowRateAir;
            fCurrentAirOxygenFlow   = fTotalFlowRateAir * arMassRatiosAirFlow(this.oMT.tiN2I.O2);
            
            fTotalFlowRateBlood    	= sum(afPartialFlowsBlood);
            fTotalFlowRateAir       = sum(afPartialFlowsAir);
            if fTotalFlowRateBlood == 0 || fTotalFlowRateAir == 0
                fAdsorptionFlowRateO2  = 0;
                fDesorptionFlowRateCO2 = 0;
            else
                arMassRatiosBloodFlow  	= afPartialFlowsBlood ./ fTotalFlowRateBlood;

                [fConcentrationBloodO2, fConcentrationBloodCO2] = this.calculateBloodConcentrations(afPP(this.oMT.tiN2I.O2), afPP(this.oMT.tiN2I.CO2));
                
                % now we subtract inlet and outlet concentration, the
                % difference is what the P2P absorbs. The concentrations are
                % calculated in kg/kg and therefore are actually mass ratios
                fAdsorptionFlowRateO2  =   fTotalFlowRateBlood * (fConcentrationBloodO2  - arMassRatiosBloodFlow(this.oMT.tiN2I.O2));
                fDesorptionFlowRateCO2 = - fTotalFlowRateBlood * (fConcentrationBloodCO2 - arMassRatiosBloodFlow(this.oMT.tiN2I.CO2));

                fAdsorptionFlowRateO2_Out  = -1;
                fDesorptionFlowRateCO2_Out = -1;
                iIteration = 0;
                mfAdsorptionFlowRate = nan(1,1000);
                mfDesorptionFlowRate = nan(1,1000);
                
                fConvergenceFactor = 0.1;
                
                % Note that a nested interval approach is not suitable for
                % this calculation, since the value for the outlet
                % adsorption flowrate of O2 depends on the values
                % calculated for CO2 and vice versa. This results in the
                % possibility that one of the boundaries in the nested
                % interval scheme is reset to a value which later on
                % belongs to the other side of the value that is correct,
                % preventing the algorithm from ever finding the correct
                % value
                while (abs(fAdsorptionFlowRateO2_Out) > 1e-9 || abs(fDesorptionFlowRateCO2_Out) > 1e-9) && iIteration < 1000
                
                    if fAdsorptionFlowRateO2 > fCurrentAirOxygenFlow
                        fAdsorptionFlowRateO2 = fCurrentAirOxygenFlow;
                    end
                    % for this calculation we have to calculate an equilibrium.
                    % Basically we have to desorb just so much CO2 that the
                    % outlet partial pressure is in equilbrium with the
                    % resulting blood concentration. The same must be done for
                    % O2.

                    % calculate new blood concentrations
                    afPartialFlowsBlood_Out = afPartialFlowsBlood;
                    afPartialFlowsBlood_Out(this.oMT.tiN2I.CO2) = afPartialFlowsBlood(this.oMT.tiN2I.CO2) - fDesorptionFlowRateCO2;
                    afPartialFlowsBlood_Out(this.oMT.tiN2I.O2)  = afPartialFlowsBlood(this.oMT.tiN2I.O2)  + fAdsorptionFlowRateO2;

                    fTotalFlowRateBlood    	= sum(afPartialFlowsBlood_Out);
                    arMassRatiosBloodFlow_Out  	= afPartialFlowsBlood_Out ./ fTotalFlowRateBlood;

                    % calculate new partial pressures
                    afPartialFlowsAir_Out = afPartialFlowsAir;
                    afPartialFlowsAir_Out(this.oMT.tiN2I.CO2) = afPartialFlowsAir(this.oMT.tiN2I.CO2) + fDesorptionFlowRateCO2;
                    afPartialFlowsAir_Out(this.oMT.tiN2I.O2)  = afPartialFlowsAir(this.oMT.tiN2I.O2)  - fAdsorptionFlowRateO2;

                    afCurrentMolsIn     = (afPartialFlowsAir_Out./ this.oMT.afMolarMass);
                    arFractions         = afCurrentMolsIn ./ sum(afCurrentMolsIn);
                    afPP_Out         	= arFractions .*  fGasPressure;
                    afPP_Out(afPP_Out < 0) = 0;

                    [fConcentrationBloodO2_Out, fConcentrationBloodCO2_Out] = this.calculateBloodConcentrations(afPP_Out(this.oMT.tiN2I.O2), afPP_Out(this.oMT.tiN2I.CO2));

                    % Now we calculate the adsorption and desorption flow for
                    % the outlet conditions. These flows should become zero and
                    % definitily not be negative!
                    fAdsorptionFlowRateO2_Out  =   fTotalFlowRateBlood * (fConcentrationBloodO2_Out  - arMassRatiosBloodFlow_Out(this.oMT.tiN2I.O2));
                    fDesorptionFlowRateCO2_Out = - fTotalFlowRateBlood * (fConcentrationBloodCO2_Out - arMassRatiosBloodFlow_Out(this.oMT.tiN2I.CO2));

                    % Now we have to get new adsorption and desorption flows.
                    % We calculate these based on how negative the above values
                    % are in comparison to the current flowrates:
                    if fAdsorptionFlowRateO2_Out > fAdsorptionFlowRateO2
                        fAdsorptionFlowRateO2 = fAdsorptionFlowRateO2_Out;
                    else
                        fAdsorptionFlowRateO2  = fAdsorptionFlowRateO2  * (fAdsorptionFlowRateO2  / (fAdsorptionFlowRateO2  - fConvergenceFactor * fAdsorptionFlowRateO2_Out));
                    end
                    if fDesorptionFlowRateCO2_Out > fDesorptionFlowRateCO2
                        fDesorptionFlowRateCO2 = fDesorptionFlowRateCO2_Out;
                    else
                        fDesorptionFlowRateCO2 = fDesorptionFlowRateCO2 * (fDesorptionFlowRateCO2 / (fDesorptionFlowRateCO2 - fConvergenceFactor * fDesorptionFlowRateCO2_Out));
                    end
                    iIteration = iIteration + 1;
                    
                    mfAdsorptionFlowRate(iIteration) = fAdsorptionFlowRateO2;
                    mfDesorptionFlowRate(iIteration) = fDesorptionFlowRateCO2;
                    % If the iteration continous to higher numbers, it is
                    % usually because of oscillations in the iteration
                    % algorithm. Therefore, we use this calculation after
                    % 100 Iterations to normalize the last 10 calculated
                    % flowrates and then continoue the iteration using this
                    % value. This results in a much faster convergence than
                    % just continouing with the normal algorithm
                    if iIteration >= 150 && mod(iIteration, 20) == 0
                        fAdsorptionFlowRateO2  = sum(mfAdsorptionFlowRate(iIteration-19:iIteration))/20;
                        fDesorptionFlowRateCO2 = sum(mfDesorptionFlowRate(iIteration-19:iIteration))/20;
                    end
                    if iIteration > 200 && iIteration < 300
                        fConvergenceFactor = 0.05;
                    elseif iIteration > 300 && iIteration < 400
                        fConvergenceFactor = 0.01;
                    elseif iIteration > 400
                        fConvergenceFactor = 10^-(round((iIteration)/100, 0));
                    end
                end
                    
                % plot(mfAdsorptionFlowRate); hold on; plot(mfDesorptionFlowRate);
            end
            arPartialsAdsorption = zeros(1, this.oMT.iSubstances);
            arPartialsAdsorption(this.oMT.tiN2I.O2) = 1;
            this.setMatterProperties(fAdsorptionFlowRateO2, arPartialsAdsorption);
            
            arPartialsDesorption = zeros(1, this.oMT.iSubstances);
            arPartialsDesorption(this.oMT.tiN2I.CO2) = 1;
            this.oCO2_P2P.setMatterProperties(fDesorptionFlowRateCO2, arPartialsDesorption);
            
            if ~isreal(fAdsorptionFlowRateO2) || ~isreal(fDesorptionFlowRateCO2)
                keyboard()
            end
        end
    end
    methods (Access = protected)
        function [fConcentrationO2, fConcentrationCO2] = calculateBloodConcentrations(this, fPartialPressureO2, fPartialPressureCO2)
            % The concentration calculation was moved here, because it
            % is called quite often and context changes are difficult
            % for matlab to handle
                
            % Calculates the new concentration of oxygen and carbon dioxide
            % that can remain in the blood based on the current partial
            % pressures of O2 and CO2
            % The Input partial pressures must be in Pa, the output
            % concentrations are in kg/kg
            
            %% NOT IN SI UNITS!!
            %
            % Equation according to "An integrated model of the human
            % ventilatory control system: the response to hypercapnia",
            % Ursino, M.; Magosso, E.; Avanzolini, G., 2001 
            % Equation A-11 and A-12. 
            % Also described in the dissertation by Markus Czupalla in
            % Equation 11-4 to 11-7. Please note that the Units for Z and
            % C_1, C_2 described in the dissertation are wrong. Refer to
            % the original source for these values!. Also note that the Z
            % value from the dissertation is just a conversion factor,
            % which is therefore not used here!
            % While the original source also provides values in kPa, the
            % paper on which that is based uses torr and the dissertation
            % also uses torr therefore it was decided to use the torr
            % values here!
            
            % The Partial pressures handed into this function are values in
            % Pa, which are therefore converted into mmHg or Torr
            fPartialPressureO2_Torr  = fPartialPressureO2  / (101325 / 760);
            fPartialPressureCO2_Torr = fPartialPressureCO2 / (101325 / 760);
            
            % O2
            fIntermediateVariableO2     = fPartialPressureO2_Torr * (1 + this.fBeta_1 * fPartialPressureCO2_Torr) / (this.fK1 * (1 + this.fAlpha_1 * fPartialPressureCO2_Torr));
            % Note according to the original source for these equations:
            % "COMPUTATIONAL EXPRESSIONS FOR BLOOD OXYGEN AND CARBON
            % DIOXIDE CONCENTRATIONS", J.L. Spencer, E. Firouztale, R.B.
            % Mellins, 1979
            % The blood is saturated with O2 at ~ 9 mmol/l
            fConcentrationO2_mmol_l     = this.fC1 * (fIntermediateVariableO2 ^ (1 / this.fa1)) / (1 + fIntermediateVariableO2 ^ (1 / this.fa1));
            
            % CO2
            fIntermediateVariableCO2    = fPartialPressureCO2_Torr * (1 + this.fBeta_2 * fPartialPressureO2_Torr) / (this.fK2 * (1 + this.fAlpha_2 * fPartialPressureO2_Torr));
            fConcentrationCO2_mmol_l    = this.fC2 * (fIntermediateVariableCO2 ^ (1 / this.fa2)) / (1 + fIntermediateVariableCO2 ^ (1 / this.fa2));
            
            % mmol would be dividing with 1000 while transforming into
            % /m^3 would multiply it with 1000 --> cancles only transform
            % into mass/m^3 instead of mol/m^3 
            % mol * kg/mol = kg/m^3 / kg/m^3 is a mass ratio (we basically
            % multiply the m^3 through wich we divide with the blood
            % density, turning it into a blood mass)
            fConcentrationO2  = fConcentrationO2_mmol_l  * this.oMT.afMolarMass(this.oMT.tiN2I.O2)  / this.fBloodDensity;
            fConcentrationCO2 = fConcentrationCO2_mmol_l * this.oMT.afMolarMass(this.oMT.tiN2I.CO2) / this.fBloodDensity;
        end
        function update(~)
            % this must be here since the normal V-HAB logic tries to
            % call the update
        end
    end
end