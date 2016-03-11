classdef PhysicalAbsorber < matter.procs.p2ps.flow
%PhysicalAbsorber P2p processor to simulate physical absorption
%   
%   The rate of absorption is computed and set as flow rate between the
%   connected phases. This flow rate is limited by the flow rate of water
%   vapor into the LCAR. Moreover the update function computes the heat
%   flow that results from absorption.
%
%   Input (by user):
%   none
%
%   Assumptions:
%   -Rate of absorption is limited by diffusion at the phase boundary.
%   Consequently, the rate of absorption depends on the concentration
%   gradient between phase boundary and bulk phase.
%   
%   -Contact surface between two phases does not change.
%
%   -Value for thickness of diffusion layer is assumed to be constant. Its
%   value is estimated
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Substance to absorb
        sSubstance;
        % Defines which species are extracted 
        arExtractPartials;        
        % Diffusion Coefficient [m2 s-1]
        fDiffCoeff;        
        % Contact Surface Absorbent and Watervapor [m2]
        fContactSurface = 2.9;
        % Thickness of diffusion layer [m]
        fThickness = 1.5e-4;
        % Heat Flow due to absoprtion process and incoming water vapor [W]
        fHeatFlow = 0;        
        % Self diffusion coefficient of water [m2 s-1] 
        fD0 = 2.3e-9;       
        % Computed rate of absorption [kg/s]
        fAbsorbRate = 0;
        % Cooling power of the absorber-radiator [W]
        fCoolingRate = 0; 
        % radiated power / cooling power of absorber-radiator [-]
        rPowerRatio = 0;
        % Enthalpy of released water vapor [J/kg]
        fEnthalpySolu = 0;
        
    end 
    
    properties (SetAccess = public, GetAccess = public)
        % Enthalpy of incomming flow [J/kg]
        fEnthalpySWME = 2443080;        
    end
     
    
    
    methods
        function this = PhysicalAbsorber(oStore, sName, sPhaseIn, sPhaseOut, sSubstance)

            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            % Species to absorb
            this.sSubstance  = sSubstance;
             
            % The p2p processor can specify which species it wants to
            % extract from the phase. A vector with relative values has to
            % be provided, with the sum of all ratios being 1 (see the
            % matter.phase.arPartialMass vector) ...
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            % ... in this case using a vector with zeros at all indices
            % except the one holding the partial mass for the species we
            % want to extract (here H2O) - which is set to 1.
            % Makes sure that only water is absorbed!
            this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance)) = 1;
 
        end
        
        
        function update(this)
            % Called whenever a flow rate changes. The two EXMES (oIn/oOut)
            % have an oPhase attribute that allows us to get the phases on
            % the left/right side.
            % Here, the oIn is always the gas phase, the oOut is the
            % solid/liquid absorber phase.
            
            % Update parameter of the diffusion process (coefficients of
            % diffusion)
            this.updateSelfDiffCoeff(); %[m2/s]
            this.updateDiffCoeff();     %[m2/s]           
            
            %% Calculate rate of absorption - flow rate [kg/s]        
            % Get flow rates and partial mass of all incoming flows
            [ afFlowRate, mrPartials ] = this.getInFlows();
            
            % The tiN2I maps the name of the species to the according index
            % in all the matter table vectors! iSpecies is the index of the
            % species we want to extract.
            iSubstance = this.oMT.tiN2I.(this.sSubstance);
            
            % Now multiply the flow rates with the according partial mass
            % of the species extracted. Then we have several flow rates,
            % representing exactly the amount of the mass of the according
            % species flowing into the absorber.
            if isempty(afFlowRate) == 0
            afFlowRate = afFlowRate .* mrPartials(:, iSubstance);
            end
            
            % Interface area
            fArea = this.fContactSurface;
            
            % Mass transfer coefficient
            fBeta = this.fDiffCoeff / this.fThickness;
            
            % Total molar concentration
            fC_l = this.oOut.oPhase.fMolarConSolu;
            
            % Molar fractions
            rXH2O_l  = this.oOut.oPhase.rXH2O;
            rXH2O_eq = this.oOut.oPhase.rXH2O_eq;
            
            % Molar Flux [mol/s]:
            fMolarFlux = fBeta * fC_l * fArea * (rXH2O_eq - rXH2O_l);         
            
            % Flow Rate [kg/s]:
            fFlowRate = this.oMT.afMolarMass(this.oMT.tiN2I.H2O) * fMolarFlux;
            
            % Just for control. fAbsorbRate is the theoretically possible
            % rate of absorption. In fact, the rate of absorption is
            % limited by the mass flow entering the LCAR
            this.fAbsorbRate = fFlowRate;
           
            % It cannot be more water absorbed than the ammount of water
            % that flows in
            if (fFlowRate > sum(afFlowRate)) && (sum(afFlowRate)>=0)
                fFlowRate = sum(afFlowRate);
            end
            
            
            %% Set new Flow Rate
            
            % Set the new flow rate. The second parameter (partial
            % masses to extract) ensures that only H2O is extracted by the
            % phase to phase processor
            this.setMatterProperties(fFlowRate, this.arExtractPartials);            

            if fFlowRate >= 0
                % Water vapor enters the absorber. Enthalpy of vapor phase
                % depends on temperature of vapor phase!
                fEnthalpy = this.fEnthalpySWME;
            else
                % Water leaves the absorber. Enthalpy of released water
                % vapor depends on temperature of solution!
                % Temperature of absorbent solution
                fTempSolu = this.oStore.toPhases.AbsorberPhase.fTemperature;
                % Compute enthalpy
                fT = 283:5:363;
                % Sample values from tables for temperatures from 283K to 308K
                % For H2O vapor enthalpy [kJ/kg]
                fh = [2518.2 2528.4 2537.5 2546.5 2555.6 2564.6...
                2573.5 2582.5 2591.3 2600.1 2608.8 2617.5 2626.1...
                2634.6 2643.0 2651.3 2659.5];                
                % Use spline function to interpolate or extrapolate
                fEnthalpy = 1000  *(spline(fT,fh, fTempSolu)); % [J/kg]
                this.fEnthalpySolu = fEnthalpy;
            end

            % Update cooling power
            this.fCoolingRate = this.fFlowRate * fEnthalpy;
            % Update power ratio
            %CHANGE THIS
            this.rPowerRatio = -this.oStore.oContainer.fRadiatedPower / this.fCoolingRate;
            % Update Heat Flow            
            this.fHeatFlow = this.fFlowRate * (this.oStore.toPhases.AbsorberPhase.fEnthalpyDilution + fEnthalpy);
            
            % Updating the heat source connected to the absorber phase.
            this.oStore.oContainer.toCapacities.Absorber.oHeatSource.setPower(this.fHeatFlow);
            this.oStore.oContainer.taint();
            % Update Absorber/Radiator Temperature
%             this.oStore.updateRadiatorTemp(this.fHeatFlow);            
           
        end
    end
    
    methods (Access = protected)  
        
        % Coefficient for diffusion of H2O molecules into LiCl solution    
        function updateDiffCoeff(this) 
            rMassFraction   = this.oStore.toPhases.AbsorberPhase.rMassFractionLiCl;
            this.fDiffCoeff = this.fD0 * (1 - (1 + (((rMassFraction)^0.5) / 0.52)^-4.92)^-0.56);
        end
        
        % Compute self-diffusion coefficient of liquid water
        function updateSelfDiffCoeff(this) 
            fTemp    = this.oStore.toPhases.AbsorberPhase.fTemperature;
            fD_star  = 1.635e-8;            %[m2/s-1]
            fT_s     = 215.05;              %[K]
            fgamma   = 2.063;               %[-]
            this.fD0 = fD_star * ((fTemp / fT_s)-1)^fgamma;
        end

        
    end
    
                
    
end

