function mfEquilibriumLoading = calculateEquilibriumLoading(this, varargin)
% Function to calculate the equilibrium loading of absorber material based
% on the toth equation. The function returns a vector with the length of
% the substances in the V-HAB matter table (also ordered accordingly) that
% contains the mass (in kg) of each substance that can be absorbed by the
% given absorber mass in equilibrium conditions.
% The function can either be given a P2P object as input or 
% afMass, afPP and fTemperature in this order.
%
% The paramteres for the Toth equation are stored in the matter table!

if length(varargin) == 1
    if ~isa(varargin{1}, 'matter.procs.p2p')
        this.throw('calculateEquilibriumLoading', 'If only one param provided, has to be a matter.procs.p2p (derivative)');
    end
    
    if any(varargin{1}.oOut.oPhase.afMass(this.abAbsorber))
        afMass          = varargin{1}.oOut.oPhase.afMass;
        fTemperature    = varargin{1}.oOut.oPhase.fTemperature;
        
        afPP            = varargin{1}.oIn.oPhase.afPP;
        
    elseif any(varargin{1}.oIn.oPhase.afMass(this.abAbsorber))
        afMass          = varargin{1}.oIn.oPhase.afMass;
        fTemperature    = varargin{1}.oIn.oPhase.fTemperature;
        
        afPP            = varargin{1}.oOut.oPhase.afPP;
        
    else
        % Output zero eq loading!!
        mfEquilibriumLoading = zeros(1,this.iSubstances);
        return
    end
else
    % TO DO: error messages if the wrong inputs are given
    afMass          = varargin{1};
    afPP            = varargin{2};
    fTemperature    = varargin{3};    
    if ~any(afMass(this.abAbsorber))
        % Output zero eq loading!!
        mfEquilibriumLoading = zeros(1,this.iSubstances);
        return
    end
end

% findout what of the mass can actually absorb something else
csAbsorbers = this.csSubstances(((afMass ~= 0) .* this.abAbsorber) ~= 0);

mfEquilibriumLoadingPerAbsorberMolsPerKG = zeros(length(csAbsorbers),this.iSubstances);
mfEquilibriumLoadingPerAbsorber = zeros(length(csAbsorbers),this.iSubstances);

for iAbsorber = 1:length(csAbsorbers)
    
    switch csAbsorbers{iAbsorber}
        
        case 'Zeolite5A'
            mfEquilibriumLoadingPerAbsorberMolsPerKG(iAbsorber,:) = calculateEquilibriumLoading_Zeolite5A(this, afPP, fTemperature);
        case 'Zeolite5A_RK38'
            mfEquilibriumLoadingPerAbsorberMolsPerKG(iAbsorber,:) = calculateEquilibriumLoading_Zeolite5A_RK38(this, afPP, fTemperature);
            
        case 'Zeolite13x'
            mfEquilibriumLoadingPerAbsorberMolsPerKG(iAbsorber,:) = calculateEquilibriumLoading_Zeolite13x(this, afPP, fTemperature);
            
        case 'SilicaGel_40'
            mfEquilibriumLoadingPerAbsorberMolsPerKG(iAbsorber,:) = calculateEquilibriumLoading_SilicaGel_40(this, afPP, fTemperature);
            
        case 'Sylobead_B125'
            mfEquilibriumLoadingPerAbsorberMolsPerKG(iAbsorber,:) = calculateEquilibriumLoading_Sylobead_B125(this, afPP, fTemperature);
            
        otherwise
            error('it seems a new absorber substances was defined without adding the required toth equation function')
    end
    
    mfEquilibriumLoadingPerAbsorber(iAbsorber,:) = (mfEquilibriumLoadingPerAbsorberMolsPerKG(iAbsorber,:).*afMass(this.tiN2I.(csAbsorbers{iAbsorber}))).*this.afMolarMass;
    
end

% The mfEquilibriumLoadingPerAbsorber vector contains the amount of each
% substance in the matter table that can be absorbed in equilibrium
% conditions for each absorber in mol/kg. This will now be transformed into
% a absolute kg value for each substance that can be absorbed and summed
% up to one vector
mfEquilibriumLoading = sum(mfEquilibriumLoadingPerAbsorber,1);
end

%% Functions to calculate the Equilibrium loading for each absorber Substance
% an individual function for each substance is used to allow varying toth
% equations for each substance to be used
function [mfQ_equ] = calculateEquilibriumLoading_Zeolite5A(this, afPP, fTemperature)
% calculating the parameters for the Toth equation according to
% ICES 2014-168 equations 22,23 and 24
mf_A = this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_A0.*exp(this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_B = this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_B0.*exp(this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_t_T = this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_T0 + this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_C0/fTemperature;

% Toth equation from ICES 2014-168 equation 21 but it was adapted for
% competitive absorption using equation 11 from AIAA 2013-3455 (also an
% ices paper). The parameters between these two equations are actually
% equal and here is the list for the parameters:
% moi           = t_0
% mTi           = c_0
% Bi            = E
% b_oi          = b_0
% b_oi * q_si   = a_0

% The toth equation itself returns the equilibrium loading in mol/kg
mfQ_equ = (mf_A .* afPP) ./ ((1 + (ones(1,this.iSubstances) .* sum(mf_B .* afPP)).^mf_t_T).^(1./mf_t_T));
end

function [mfQ_equ] = calculateEquilibriumLoading_Zeolite5A_RK38(this, afPP, fTemperature)
% calculating the parameters for the Toth equation according to
% ICES 2014-168 equations 22,23 and 24
mf_A = this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_A0.*exp(this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_B = this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_B0.*exp(this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_t_T = this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_T0 + this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_C0/fTemperature;

% Toth equation from ICES 2014-168 equation 21 but it was adapted for
% competitive absorption using equation 11 from AIAA 2013-3455 (also an
% ices paper). The parameters between these two equations are actually
% equal and here is the list for the parameters:
% moi           = t_0
% mTi           = c_0
% Bi            = E
% b_oi          = b_0
% b_oi * q_si   = a_0

% The toth equation itself returns the equilibrium loading in mol/kg
mfQ_equ = (mf_A .* afPP) ./ ((1 + (ones(1,this.iSubstances) .* sum(mf_B .* afPP)).^mf_t_T).^(1./mf_t_T));
end
function [mfQ_equ] = calculateEquilibriumLoading_Zeolite13x(this, afPP, fTemperature)
% calculating the parameters for the Toth equation according to
% ICES 2014-168 equations 22,23 and 24
mf_A = this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_A0.*exp(this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_B = this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_B0.*exp(this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_t_T = this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_T0 + this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_C0/fTemperature;

% Toth equation from ICES 2014-168 equation 21 but it was adapted for
% competitive absorption using equation 11 from AIAA 2013-3455 (also an
% ices paper). The parameters between these two equations are actually
% equal and here is the list for the parameters:
% moi           = t_0
% mTi           = c_0
% Bi            = E
% b_oi          = b_0
% b_oi * q_si   = a_0

% The toth equation itself returns the equilibrium loading in mol/kg
mfQ_equ = (mf_A .* afPP) ./ ((1 + (ones(1,this.iSubstances) .* sum(mf_B .* afPP)).^mf_t_T).^(1./mf_t_T));
end

function [mfQ_equ] = calculateEquilibriumLoading_SilicaGel_40(this, afPP, fTemperature)
% calculating the parameters for the Toth equation according to
% ICES 2014-168 equations 22,23 and 24
mf_A = this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_A0.*exp(this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_B = this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_B0.*exp(this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_t_T = this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_T0 + this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_C0/fTemperature;

% Toth equation from ICES 2014-168 equation 21 but it was adapted for
% competitive absorption using equation 11 from AIAA 2013-3455 (also an
% ices paper). The parameters between these two equations are actually
% equal and here is the list for the parameters:
% moi           = t_0
% mTi           = c_0
% Bi            = E
% b_oi          = b_0
% b_oi * q_si   = a_0

% The toth equation itself returns the equilibrium loading in mol/kg
mfQ_equ = (mf_A .* afPP) ./ ((1 + (ones(1,this.iSubstances) .* sum(mf_B .* afPP)).^mf_t_T).^(1./mf_t_T));
end

function [mfQ_equ] = calculateEquilibriumLoading_Sylobead_B125(this, afPP, fTemperature)
% calculating the parameters for the Toth equation according to
% ICES 2014-168 equations 22,23 and 24
mf_A = this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_A0.*exp(this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_B = this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_B0.*exp(this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_E/fTemperature);
mf_t_T = this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_T0 + this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_C0/fTemperature;

% Toth equation from ICES 2014-168 equation 21 but it was adapted for
% competitive absorption using equation 11 from AIAA 2013-3455 (also an
% ices paper). The parameters between these two equations are actually
% equal and here is the list for the parameters:
% moi           = t_0
% mTi           = c_0
% Bi            = E
% b_oi          = b_0
% b_oi * q_si   = a_0

% The toth equation itself returns the equilibrium loading in mol/kg
mfQ_equ = (mf_A .* afPP) ./ ((1 + (ones(1,this.iSubstances) .* sum(mf_B .* afPP)).^mf_t_T).^(1./mf_t_T));
end