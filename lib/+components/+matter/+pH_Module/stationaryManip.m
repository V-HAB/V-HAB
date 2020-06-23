classdef stationaryManip < matter.manips.substance.stationary & components.matter.pH_Module.baseManip
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
        
        % The time we assume it takes for the pH manip to reach the newly
        % calculated pH value in s
        fConversionTime = 20;
    end
    
    
    methods
        function this = stationaryManip(sName, oPhase, fConversionTime)
            this@matter.manips.substance.stationary(sName, oPhase);
            this@components.matter.pH_Module.baseManip(oPhase);
            
            if nargin > 2
                this.fConversionTime = fConversionTime;
            end
        end
    end
    
    methods (Access = protected)
        function update(this)
            
            if any(this.oPhase.arPartialMass(this.abDissociation)) && this.oPhase.afMass(this.oMT.tiN2I.H2O) > 10^-12
                arPartials = this.oPhase.arPartialMass(this.abRelevantSubstances);
                
                if all(abs(((this.arLastPartials - arPartials) ./ (this.arLastPartials + 1e-8))) < this.rMaxChange)
                    return
                end
                this.arLastPartials = arPartials;
                
                fVolume = this.oPhase.fMass / this.oPhase.fDensity;
                % Concentrations in mol/L!
                afInitialConcentrations = ((this.oPhase.afMass ./ this.oMT.afMolarMass) ./ fVolume);

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
                
                fInitialMassSum = this.oPhase.fMass ./ fVolume; % [kg/L]
                
                afConcentrations = this.calculateNewConcentrations(afInitialConcentrations, fInitialMassSum, this.fpH);
                
                afConcentrationDifference = afConcentrations' - afInitialConcentrations;

                % Set very small concentration changes to 0
                afConcentrationDifference(abs(afConcentrationDifference) < 1e-16) = 0;
                
                % Here we assume that it converts within 20 s, which means
                % we divide it with 20
                this.afConversionRates = afConcentrationDifference .* fVolume .* this.oMT.afMolarMass ./ this.fConversionTime;
                
            else
                this.afConversionRates = zeros(1, this.oMT.iSubstances); %[kg/s]
            end
            
            update@matter.manips.substance.stationary(this, this.afConversionRates);
        end
    end
end