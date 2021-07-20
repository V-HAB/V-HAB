classdef flowManip < matter.manips.substance.flow & components.matter.pH_Module.baseManip
    %% pH flowManip
    % This manipulator can be used to calculate the pH value in an aquaous
    % solution and converting all participating substances correspondingly
    % If new substances where added to the matter table which take part in
    % the pH value calculation, you have to adjust the miComplex variable
    % accordingly! Substances that do not directly dissocicate with water
    % like for example CaCO3 must be split seperatly before they are
    % considered correctly in these equations!
    %
    % The solved system of equations includes the acid/base dissociations
    % charge balance, mass balance and molar balances of inidivual ion
    % groups (e.g. PO4^(3-) in all forms like H3PO4 etc)
    properties (SetAccess = protected, GetAccess = public)
        % Current pH Value of the phase, at the inlet of the phase
        fpH_Inlet;
    end
    
    
    methods
        function this = flowManip(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            this@components.matter.pH_Module.baseManip(oPhase);
            
            if ~oPhase.bFlow
                error('Flow manips only work with flow phases')
            end
            
        end
        function calculateConversionRate(this, afInFlowRates, aarInPartials, ~)
            %getting inflowrates
            afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
            % Since we also consider P2P flowrates for these in flows, we
            % have to check to not use negative total flowrates here:
            afPartialInFlows(afPartialInFlows < 0) = 0;
            
            if any(afPartialInFlows(this.abDissociation)) && afPartialInFlows(this.oMT.tiN2I.H2O) > 10^-12
                afFlows = afPartialInFlows(this.abRelevantSubstances);
                arPartials = afFlows ./ sum(afFlows);
                
                if all(abs(((this.arLastPartials - arPartials) ./ (this.arLastPartials + 1e-18))) < this.rMaxChange)
                    return
                end
                this.arLastPartials = arPartials;
                
                % Volumetric flowrate in l/s!
                fVolumetricFlowRate = (sum(afPartialInFlows) / this.oPhase.fDensity) * 1000;

                % Concentrations in mol/L!
                afInitialConcentrations = ((afPartialInFlows ./ this.oMT.afMolarMass) ./ fVolumetricFlowRate);

                this.fpH_Inlet = calculate_pHValue(this, afInitialConcentrations);
                
                fInitialMassSum = sum(afPartialInFlows(this.abRelevantSubstances)) / fVolumetricFlowRate; % [kg/L]
                
                if fInitialMassSum == 0
                    afConcentrationDifference = zeros(1, this.oMT.iSubstances);
                else
                    afConcentrations = this.calculateNewConcentrations(afInitialConcentrations, fInitialMassSum, this.fpH_Inlet);

                    afConcentrationDifference = afConcentrations' - afInitialConcentrations;
                end
                % Set very small concentration changes to 0
                afConcentrationDifference(abs(afConcentrationDifference) < 1e-16) = 0;

                this.afConversionRates = afConcentrationDifference .* fVolumetricFlowRate .* this.oMT.afMolarMass;
                
                afFinalConcentrations = (((afPartialInFlows + this.afConversionRates) ./ this.oMT.afMolarMass) ./ fVolumetricFlowRate);
                
                this.fpH = calculate_pHValue(this, afFinalConcentrations);
            else
                this.afConversionRates = zeros(1, this.oMT.iSubstances); %[kg/s]
            end
            this.update();
        end
    end
    
    methods (Access = protected)
        function update(this)
            update@matter.manips.substance.flow(this, this.afConversionRates);
        end
    end
end