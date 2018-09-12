classdef AbsorbentPhase < matter.phases.liquid
%AbsorbentPhase This phase represents LiCl-Water Solution
%   
%   When water is absorbed, the phase becomes filled with matter. Thus the
%   mass property of the phase object indicates how much water has been
%   absorbed after a given time. Furthermore, this phase class has
%   functions to compute important characteristics of the lithium chloride
%   solution (heat capacity, density, enthalpy of dissolution).
%
%   Input:
%   from LCARAbsorber
%
%   Assumptions:
%   - for LiCl mass frac > 60%, enthalpy change is assumed to be
%   independent from the LiCl mass fraction
%   - equation for equilibrium vapor pressure vaild for 0-90% LiCl
    
    properties (SetAccess = protected, GetAccess = public)       
       
        % Mass Concentarion of LiCl [kg A/ kg total]
        rMassFractionLiCl;      
        % Masse an LiCl [kg]
        fMassLiCl;       
        % Total Mass [kg]
        fMassTotal;        
        % Molar concentration of solution [mol/m3]
        fMolarConSolu;        
        % Amount of H2O [mol]
        fNH2O;        
        % Amount of LiCl [mol]
        fNLiCl;       
        % Molar fraction of H2O [-]
        rXH2O;      
        % Molar fraction at equilibrium [-]
        rXH2O_eq = 1;        
        % Heat capacity [J / K]
        fHeatCap;
        % Heat of dissolution [J/kg]
        fEnthalpyDilution;
        
    end
    
    properties (SetAccess = public, GetAccess = public)
        % Pressure of SWME vapor side (or pressure
        % of regeneration system) [Pa]
        fEvapPressure = 2300;
    end
    
    methods
        %% Constructor
        function this = AbsorbentPhase(oStore, sName, tfMasses, fTemperature)
            
            % Initialize constructor of superclass 'matter.phases.liquid'
            this@matter.phases.liquid(oStore, sName, tfMasses, fTemperature);
            
            % Initial mass of absorbent (lithium chloride)
            this.fMassLiCl = tfMasses.LiCl;
            
            % Initial mass fraction
            this.rMassFractionLiCl = tfMasses.LiCl / this.fMass;
            
            % Amount of LiCl
            this.fNLiCl = tfMasses.LiCl / this.oMT.afMolarMass(this.oMT.tiN2I.LiCl);
            
            % Amount of H2O
            this.fNH2O = tfMasses.H2O / this.oMT.afMolarMass(this.oMT.tiN2I.H2O);
            this.rXH2O = this.fNH2O / (this.fNH2O + this.fNLiCl);
            
            % Density
            this.updateDensitySol();            
            
            % Molar concentration
            this.fMolarConSolu = (this.fNH2O + this.fNLiCl) * this.fDensity * (1 / this.fMass);
            
            % Update Heat Capacity
            this.updateSpecificHeatCapacity();
            
            % Update enthalpy of dilution
            this.updateEnthalpyDil();
 
        end
        
        
        %% Update Function
        function this = update(this)
            update@matter.phases.liquid(this);
            
            % Molar fraction of H2O [mol]
            this.fNH2O = (this.afMass(this.oMT.tiN2I.H2O))/...
                (this.oMT.afMolarMass(this.oMT.tiN2I.H2O));
            this.rXH2O = this.fNH2O/(this.fNH2O + this.fNLiCl);           
            % Update mass fraction of LiCl
            this.rMassFractionLiCl = this.fMassLiCl/this.fMass;            
            % Update density
            this.updateDensitySol();            
            % Update molar concentration
            this.fMolarConSolu = (this.fNH2O + this.fNLiCl) * this.fDensity * (1 / this.fMass);            
            % Update Heat Capacity
            this.updateSpecificHeatCapacity();            
            % Update enthalpy of dilution
            this.updateEnthalpyDil();            
            % Update equilibrium molar fraction
            this.updateEquiMolarFrac();

        end
        
    end
    
    methods
        %% Calculate Density of the Solution (Absorbent Phase)
        function updateDensitySol(this)            
            % Density formula only valid for temperatures > 0°C
            if this.fTemperature < 273.15
                this.throw('AbsorbentPhase',...
                    'Temperature below freezing point (< 0°C)! Equation for solution density invalid');
            else
                fTemp = this.fTemperature;
            end
                        
            if this.rMassFractionLiCl <= 0.6
                fTheta = fTemp / 647;
                fTau   = 1 - fTheta;
                mB     = [1 1.994 1.099 -0.509 -1.762 -45.901 -723692.262];
                mTau   = [1; (fTau^(1/3)); (fTau^(2/3)); (fTau^(5/3)); (fTau^(16/3)); (fTau^(43/3)); (fTau^(110/3))];
                
                fDensityH2Osat = 322 *(mB * mTau);
                
                % Calculate density of aqueous LiCl solution
                mRoh   = [1 0.541 -0.304 0.101];
                fR     = this.rMassFractionLiCl / (1 - this.rMassFractionLiCl);
                mRatio = [1; (fR^1); (fR^2); (fR^3)];
                
                fDensitySolution = fDensityH2Osat * (mRoh * mRatio);
             else
                % Linear interpolation necessary between 0.6<rMassRatio<1
                % fDensity = fMassFrac * fm + ft (fm, ft parameters)
                fDensityMax = 2070;
                fTheta      = fTemp / 647;
                fTau        = 1-fTheta;
                mB          = [1 1.994 1.099 -0.509 -1.762 -45.901 -723692.262];
                mTau        = [1; (fTau^(1/3)); (fTau^(2/3)); (fTau^(5/3)); (fTau^(16/3)); (fTau^(43/3)); (fTau^(110/3))];
                
                fDensityH2Osat = 322 * (mB * mTau);
                
                mRoh   = [1 0.541 -0.304 0.101];                
                fR     = 0.6 / (1 - 0.6);
                mRatio = [1; (fR^1); (fR^2); (fR^3)];
                
                fDensityLimit = fDensityH2Osat * (mRoh * mRatio);
                
                fm = (fDensityMax - fDensityLimit) / 0.4;            
                ft = fDensityMax - fm;
                
                fDensitySolution = fm * this.rMassFractionLiCl + ft;  
                                
            end
            
            if fDensitySolution < 0
                this.throw('AbsorbentPhase', 'Density of absorbent is negative! Makes no sense! Check Temperature and Mass Fraction.');
            else            
                this.fDensity = fDensitySolution;
            end
        end
        
        
        
        
        %% Update equilibrium molar fraction of H2O
        % Compute equilibrium molar fraction based on empirical vapor
        % pressure equation
        function updateEquiMolarFrac(this)
            fT        = this.fTemperature;
            fPressure = this.fEvapPressure;
            fTau      = 1 - (fT / 647);
            mA        = [-7.858 1.840 -11.781 22.671 -15.939 1.775];
            x         = mA * [fTau; fTau^1.5; fTau^3; fTau^3.5; fTau^4; fTau^7.5];
            pH2O      = (22.07e6) * exp(x / (1 - fTau));
            
            % Numerical solution of the pressure equation. Set options:
            % TypicalX ensures stability of the algorithm
            % (fsolve uses TypicalX for scaling finite differences for
            % gradient estimation)
            options = optimoptions('fsolve','Display','off','TypicalX',0.9);
            
            hFunction = @(x) pH2O * (1 - ((1 + ((x / 0.362)^(-4.75)))^(-0.4)) - 0.03...
                    * exp(-((x - 0.1)^2) / 0.005)) * (2 - ((1 + ((x / 0.28)^4.3))^0.6)...
                    + (((1 + ((x / 0.21)^5.1))^0.49) - 1) * fT / 647) - fPressure;
            
            % Solve equation for equilibrium mass fraction of LiCl
            rZetaLiCl_eq = fsolve(hFunction, 0, options);
            
            % From LiCl mass fraction to H2O molar fraction
            fNH2O_eq      = (1 / (this.oMT.afMolarMass(this.oMT.tiN2I.H2O))) * ((this.fMassLiCl / rZetaLiCl_eq) - this.fMassLiCl);
            this.rXH2O_eq = fNH2O_eq / (fNH2O_eq + this.fNLiCl); 
            
            if rZetaLiCl_eq >= 1
                this.rXH2O_eq = 0.001;
                disp('Note: Equilibrium mass fraction of LiCl has reached 100%');                
            elseif rZetaLiCl_eq <= 0
                this.rXH2O_eq = 1;
            end
            
            if (rZetaLiCl_eq > 1.5) || (rZetaLiCl_eq < -1)
                disp('Warning!: No useful values for LiCl equilibrium mass fraction. Check fsolve settings!');
            end
        end

       
        
        
        %% Heat Capacity of LiCl solution
        function updateSpecificHeatCapacity(this)
            if this.fTemperature <= 228
                this.throw('AbsorbentPhase', 'Equation for heat capacity invalid (Temperature too low!)');
            end
                        
            fTheta = (this.fTemperature / 228) - 1;
        
            % Modified Sato Equation for specific Heat Capacity of Water
            if this.fTemperature > 273
                fAHeatCap = 88.7891;
                mHeatCapParams = [-120.1958 -16.9264 52.4654 0.10826 0.46988];
            else
                fAHeatCap = 830.54602;
                mHeatCapParams = [-1247.52013 -68.60350 491.27650 -1.80692 -137.51511];
            end
            
            mThetaHeatCap = [(fTheta^0.02); (fTheta^0.04); (fTheta^0.06); (fTheta^1.8); (fTheta^8)];
            fWaterHeatCap = fAHeatCap + mHeatCapParams * mThetaHeatCap;
            
            % Specific Heat Capacity of LiCl-Water Solutions
            if this.rMassFractionLiCl < 0.31
               this.throw('AbsorbentPhase', 'Equation for heat capacity invalid (Mass fraction LiCl too low! (<30%)) '); 
            end
            
            % Parameters f1, f2 for heat capacity equation
            f1 = 0.12825 + 0.62934 * this.rMassFractionLiCl;
            
            mF     = [58.5225 -105.6343 47.7948];
            mTheta = [(fTheta^0.02); (fTheta^0.04); (fTheta^0.06)];
            f2     = mF * mTheta;
            
            %CHECK What is this factor 1000 for? Do we need it?
            this.fSpecificHeatCapacity = fWaterHeatCap * (1 - (f1 * f2)) * 1000;
            
            this.fHeatCap = this.fMass * this.fSpecificHeatCapacity;
            this.fTotalHeatCapacity = this.fHeatCap;
        end
        
        
        %% Overloading phase.m's getTotalHeatCapacity() method
        function fTotalHeatCapacity = getTotalHeatCapacity(this)
            % Returns the total heat capacity of the phase. 
            
            % We'll only calculate this again, if a certain amount of time
            % has passed since the last update. This value is set using the
            % fMinimalTimeBetweenHeatCapacityUpdates property, which is set
            % to 1 second by default. This is to reduce the computational
            % load and may be removed in the future, especially if the
            % calculateSpecificHeatCapactiy() method and the findProperty()
            % method of the matter table have been substantially
            % accelerated. One second is also the fixed timestep of the
            % thermal solver.
            if ~(this.oTimer.fTime < this.fLastTotalHeatCapacityUpdate + this.fMinimalTimeBetweenHeatCapacityUpdates)
                this.updateSpecificHeatCapacity();
                this.fLastTotalHeatCapacityUpdate = this.oTimer.fTime;
            end
            
            fTotalHeatCapacity = this.fHeatCap;
            
        end
        
        
        %% Compute enthalpy of dissolution
        function updateEnthalpyDil(this)
            
            % Parameters for enthalpy equation
            fH5 = 169.105;
            fH6 = 457.85;
            % Set lower bound for enthalpy of dissolution
            if this.fTemperature < 229
                this.throw('PhysicalAbsorber','Temperature below freezing point!');
            else
                fTheta = (this.fTemperature / 228) - 1;
                fRefEnthalpy = fH5 + fH6 * fTheta;
                
                if this.rMassFractionLiCl > 0.6
                    %CHECK What is this factor 1000 for? Do we need it?
                    this.fEnthalpyDilution = 1000 * fRefEnthalpy;
                else
                    fH1   =  0.845;
                    fH2   = -1.965;
                    fH3   = -2.265;
                    fH4   =  0.6;
                    fZeta = this.rMassFractionLiCl / (fH4 - this.rMassFractionLiCl);
                    %CHECK What is this factor 1000 for? Do we need it?
                    this.fEnthalpyDilution = 1000 * fRefEnthalpy * ((1 + (fZeta / fH1)^fH2)^fH3);
                end
            end
            
        end
        
             
    end
    
end

