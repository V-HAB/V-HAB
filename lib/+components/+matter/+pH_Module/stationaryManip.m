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
                
                if all(abs(((this.arLastPartials - arPartials) ./ (arPartials + 1e-8))) < this.rMaxChange)
                    return
                end
                this.arLastPartials = arPartials;
                
                fVolume = (this.oPhase.fMass / this.oPhase.fDensity) * 1000;
                % Concentrations in mol/l!
                afInitialConcentrations = ((this.oPhase.afMass ./ this.oMT.afMolarMass) ./ fVolume);
                
                this.fpH = calculate_pHValue(this, afInitialConcentrations);
                
                if isinf(this.fpH)
                    this.fpH = 7;
                end
                
                fInitialMassSum = sum(this.oPhase.afMass(this.abRelevantSubstances)) ./ fVolume; % [kg/l]
                
                afConcentrations = this.calculateNewConcentrations(afInitialConcentrations, fInitialMassSum, this.fpH);
                
                afConcentrationDifference = zeros(1, this.oMT.iSubstances);
                afConcentrationDifference(this.abRelevantSubstances) = afConcentrations(this.abRelevantSubstances)' - afInitialConcentrations(this.abRelevantSubstances);

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