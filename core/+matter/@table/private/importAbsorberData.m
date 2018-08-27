function importAbsorberData(this)
%IMPORTABSORBERDATA Loads all data on absorber substances into the matter
%table
%   This function manipulates the ttxMatter property of the matter table
%   class and adds properties to several substances that are specific to
%   the absorption processes they are part of. Mainly these are the
%   parameters of the Toth equation.

% First we create a boolean array that can be used to quickly identify the
% substances that are absorbers. Since this may be used in other functions
% as well, we make it a property of the matter table class. 
this.abAbsorber = false(1,this.iSubstances);
this.abAbsorber(this.tiN2I.Zeolite5A)       = true;
this.abAbsorber(this.tiN2I.Zeolite5A_RK38)  = true;
this.abAbsorber(this.tiN2I.Zeolite13x)      = true;
this.abAbsorber(this.tiN2I.SilicaGel_40)    = true;
this.abAbsorber(this.tiN2I.Sylobead_B125)   = true;

% Initializing the data fields we want to fill
csAbsorbers = this.csSubstances(this.abAbsorber);
for iAbsorber = 1:length(csAbsorbers)
    this.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.tToth.mf_A0 = zeros(1,this.iSubstances);
    this.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.tToth.mf_B0 = zeros(1,this.iSubstances);
    this.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.tToth.mf_E  = zeros(1,this.iSubstances);
    this.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.tToth.mf_T0 = zeros(1,this.iSubstances);
    this.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.tToth.mf_C0 = zeros(1,this.iSubstances);
    
    this.ttxMatter.(csAbsorbers{iAbsorber}).tAbsorberParameters.mfAbsorptionEnthalpy = zeros(1,this.iSubstances);
end


% ALL Parameters according to ICES-2014-168
% Zeolite 5A
% Unit of the Factor is mol/(kg Pa)
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_A0(this.tiN2I.CO2)    = 9.875E-10;
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_A0(this.tiN2I.H2O)    = 1.106E-11;

% Unit of the Factor is 1/Pa
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_B0(this.tiN2I.CO2)    = 6.761E-11;
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_B0(this.tiN2I.H2O)    = 4.714E-13;

% Unit of the Factor is K
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_E(this.tiN2I.CO2)     = 5.625E3;
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_E(this.tiN2I.H2O)     = 9.955E3;

% Unit of the Factor is -
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_T0(this.tiN2I.CO2)    = 2.700E-1;
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_T0(this.tiN2I.H2O)    = 3.548E-1;

% Unit of the Factor is K
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_C0(this.tiN2I.CO2)    = -2.002E1;
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_C0(this.tiN2I.H2O)    = -5.114E1;

% Absorption Enthalpy for the different substances in J/mol
this.ttxMatter.Zeolite5A.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.CO2)    = -38000;
this.ttxMatter.Zeolite5A.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.H2O)    = -45000;


% Zeolite 5A_RK38 - Parameters for toth identical to 5A
% Unit of the Factor is mol/(kg Pa)
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_A0(this.tiN2I.CO2)    = 9.875E-10;
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_A0(this.tiN2I.H2O)    = 1.106E-11;

% Unit of the Factor is 1/Pa
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_B0(this.tiN2I.CO2)    = 6.761E-11;
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_B0(this.tiN2I.H2O)    = 4.714E-13;

% Unit of the Factor is K
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_E(this.tiN2I.CO2)     = 5.625E3;
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_E(this.tiN2I.H2O)     = 9.955E3;

% Unit of the Factor is -
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_T0(this.tiN2I.CO2)    = 2.700E-1;
this.ttxMatter.Zeolite5A.tAbsorberParameters.tToth.mf_T0(this.tiN2I.H2O)    = 3.548E-1;

% Unit of the Factor is K
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_C0(this.tiN2I.CO2)    = -2.002E1;
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.tToth.mf_C0(this.tiN2I.H2O)    = -5.114E1;

% Absorption Enthalpy for the different substances in J/mol
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.CO2)    = -38000;
this.ttxMatter.Zeolite5A_RK38.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.H2O)    = -45000;


% Zeolite 13x
% Unit of the Factor is mol/(kg Pa)
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_A0(this.tiN2I.CO2)    = 6.509E-6;
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_A0(this.tiN2I.H2O)    = 3.634E-9;

% Unit of the Factor is 1/Pa
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_B0(this.tiN2I.CO2)    = 4.884E-7;
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_B0(this.tiN2I.H2O)    = 2.408E-10;

% Unit of the Factor is K
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_E(this.tiN2I.CO2)     = 2.991E3;
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_E(this.tiN2I.H2O)     = 6.852E3;

% Unit of the Factor is -
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_T0(this.tiN2I.CO2)    = 7.487E-2;
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_T0(this.tiN2I.H2O)    = 3.974E-1;

% Unit of the Factor is K
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_C0(this.tiN2I.CO2)    = 3.805E1;
this.ttxMatter.Zeolite13x.tAbsorberParameters.tToth.mf_C0(this.tiN2I.H2O)    = -4.199;

% Absorption Enthalpy for the different substances in J/mol
this.ttxMatter.Zeolite13x.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.CO2)    = -40000;
this.ttxMatter.Zeolite13x.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.H2O)    = -55000;


% Silica Gel 40
% Unit of the Factor is mol/(kg Pa)
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_A0(this.tiN2I.CO2)    = 7.678E-9;
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_A0(this.tiN2I.H2O)    = 1.767E-1;

% Unit of the Factor is 1/Pa
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_B0(this.tiN2I.CO2)    = 5.164E-10;
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_B0(this.tiN2I.H2O)    = 2.787E-8;

% Unit of the Factor is K
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_E(this.tiN2I.CO2)     = 2.330E3;
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_E(this.tiN2I.H2O)     = 1.093E3;

% Unit of the Factor is -
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_T0(this.tiN2I.CO2)    = -3.053E-1;
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_T0(this.tiN2I.H2O)    = -1.190E-3;

% Unit of the Factor is K
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_C0(this.tiN2I.CO2)    = 2.386E2;
this.ttxMatter.SilicaGel_40.tAbsorberParameters.tToth.mf_C0(this.tiN2I.H2O)    = 2.213E1;

% Absorption Enthalpy for the different substances in J/mol
this.ttxMatter.SilicaGel_40.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.CO2)    = -40000;
this.ttxMatter.SilicaGel_40.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.H2O)    = -50200;


% Sylobead_B125 - Parameters for toth identical to 5A
% Unit of the Factor is mol/(kg Pa)
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_A0(this.tiN2I.CO2)    = 7.678E-9;
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_A0(this.tiN2I.H2O)    = 1.767E-1;

% Unit of the Factor is 1/Pa
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_B0(this.tiN2I.CO2)    = 5.164E-10;
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_B0(this.tiN2I.H2O)    = 2.787E-8;

% Unit of the Factor is K
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_E(this.tiN2I.CO2)     = 2.330E3;
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_E(this.tiN2I.H2O)     = 1.093E3;

% Unit of the Factor is -
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_T0(this.tiN2I.CO2)    = -3.053E-1;
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_T0(this.tiN2I.H2O)    = -1.190E-3;

% Unit of the Factor is K
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_C0(this.tiN2I.CO2)    = 2.386E2;
this.ttxMatter.Sylobead_B125.tAbsorberParameters.tToth.mf_C0(this.tiN2I.H2O)    = 2.213E1;

% Absorption Enthalpy for the different substances in J/mol
this.ttxMatter.Sylobead_B125.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.CO2)    = -40000;
this.ttxMatter.Sylobead_B125.tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.H2O)    = -50200;

end

