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
    end
    
    
    methods
        function this = flowManip(sName, oPhase)
            this@matter.manips.substance.flow(sName, oPhase);
            this@components.matter.pH_Module.baseManip(oPhase);
            
            if ~oPhase.bFlow
                error('Flow manips only work with flow phases')
            end
            
        end
        function calculateConversionRate(this, afInFlowRates, aarInPartials)
            %getting inflowrates
            afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
            % Since we also consider P2P flowrates for these in flows, we
            % have to check to not use negative total flowrates here:
            afPartialInFlows(afPartialInFlows < 0) = 0;
            
            if any(afPartialInFlows(this.abDissociation)) && afPartialInFlows(this.oMT.tiN2I.H2O) > 10^-12
                afFlows = afPartialInFlows(this.abRelevantSubstances);
                arPartials = afFlows ./ sum(afFlows);
                
                if all(abs(((this.arLastPartials - arPartials) ./ (this.arLastPartials + 1e-8))) < this.rMaxChange)
                    return
                end
                this.arLastPartials = arPartials;
                
                % Volumetric flowrate in l/s!
                fVolumetricFlowRate = (sum(afPartialInFlows) / this.oPhase.fDensity) * 1000;

                % Concentrations in mol/L!
                afInitialConcentrations = ((afPartialInFlows ./ this.oMT.afMolarMass) ./ fVolumetricFlowRate);

                if this.fpH > 8
                    % For high pH Values it is more stable to use the OH
                    % concentration for the pH Calculation
                    this.fpH = (-log10(this.oMT.afDissociationConstant(this.oMT.tiN2I.H2O)) - -log10(afInitialConcentrations(this.oMT.tiN2I.OH)));
                elseif this.fpH < 6
                    this.fpH = -log10(afInitialConcentrations(this.oMT.tiN2I.Hplus));
                else
                    fpH_OH = (-log10(this.oMT.afDissociationConstant(this.oMT.tiN2I.H2O)) - -log10(afInitialConcentrations(this.oMT.tiN2I.OH)));
                    fpH_H  = -log10(afInitialConcentrations(this.oMT.tiN2I.Hplus));
                    
                    if isinf(fpH_OH) && isinf(fpH_H)
                        this.fpH = 7;
                    else
                        % Since we do not know exactly at what point the
                        % calculation becomes more stable, we check here
                        % what calculation has the smaller difference
                        if abs(fpH_OH - this.fpH) < abs(fpH_H - this.fpH)
                            this.fpH = fpH_OH;
                        else
                            this.fpH = fpH_H;
                        end
                    end
                end
                
                if isinf(this.fpH)
                    this.fpH = 7;
                end
                
                fInitialMassSum = sum(afPartialInFlows(this.abRelevantSubstances)) / fVolumetricFlowRate; % [kg/L]
                
                afConcentrations = this.calculateNewConcentrations(afInitialConcentrations, fInitialMassSum, this.fpH);
                
                afConcentrationDifference = afConcentrations' - afInitialConcentrations;

                % Set very small concentration changes to 0
                afConcentrationDifference(abs(afConcentrationDifference) < 1e-16) = 0;

                this.afConversionRates = afConcentrationDifference .* fVolumetricFlowRate .* this.oMT.afMolarMass;
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