classdef FlowPhase < matter.phases.gas
%FlowPhase Class for water vapor phase in LCAR Absorber
%   
%   Phase object represents water vapor flowing through the absorber. The
%   property fPressure equals the equilibrium vapor pressure at the surface
%   of the absorbent!
%
%   Input:
%   -
%
%   Assumptions:
%   Thermodynamic equilibrium at the phase boundary between water vapor and
%   absorbent! fPressure is not the pressure in the absorber, it is the
%   equilibrium vapor pressure at the SURFACE (phase boundary) of the
%   absorbent

     methods
        %% Constructor:
        function this = FlowPhase(oStore, sName, tfMasses, fVolume, fTemp)
            
            this@matter.phases.gas(oStore, sName, tfMasses, fVolume, fTemp);
        end
        
        %% Update:
        function this = update(this)
            % Compute equilibrium vapor pressure
            rMassFractionLiCl = this.oStore.toPhases.AbsorberPhase.rMassFractionLiCl;
            
            fTemperature  = this.oStore.toPhases.AbsorberPhase.fTemperature;
            fPi25  = 1 - ((1 + (rMassFractionLiCl / 0.362)^ -4.75 )^ -0.4) - 0.03 * exp(-((rMassFractionLiCl - 0.1)^2) / 0.005);
            fA     = 2 - ( 1 + (rMassFractionLiCl / 0.28)^4.3 )^0.6;
            fB     =    (( 1 + (rMassFractionLiCl / 0.21)^5.1 )^0.49) - 1;
            ftheta = fTemperature / 647;
            
            % Compute water vapor pressure
            ftau = 1 - (fTemperature / 647);
            mA   = [-7.858 1.840 -11.781 22.671 -15.939 1.775];
            x    = mA * [ftau; ftau^1.5; ftau^3; ftau^3.5; ftau^4; ftau^7.5];
            pH2O = (22.07e6) * exp(x / (1 - ftau));
                       
            % Compute equilibrium pressure of saturated water vapor above
            % aqueous solutions of LiCl
            this.fPressure = fPi25 * (fA + fB * ftheta) * pH2O;
            
            % pressure cannot be negative
            if this.fPressure < 0
                this.fPressure = 0;
            end
    
        end
        
    end
end

