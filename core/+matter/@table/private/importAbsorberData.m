function importAbsorberData(this)
%IMPORTABSORBERDATA Loads all data on absorber substances into the matter
%table
%   This function manipulates the ttxMatter property of the matter table
%   class and adds properties to several substances that are specific to
%   the absorption processes they are part of. Mainly these are the
%   parameters of the Toth equation.

% First we take a look at the properties of the constant data class
% 'AbsorberData'. There is a single property for each absorber substance.
csAbsorbers = properties('matter.data.AbsorberData');

% Counting the number of absorbers we have
iNumberOfAbsorbers = length(csAbsorbers);

% Now we create a boolean array that can be used to quickly identify the
% substances that are absorbers. Since this may be used in other functions
% as well, we make it a property of the matter table class. 
this.abAbsorber = false(1,this.iSubstances);

% Now we loop through each of the substances and add the data to the
% ttxMatter struct.
for iSubstance = 1:iNumberOfAbsorbers

    % Setting the item in the abAbsorber array to true
    this.abAbsorber(this.tiN2I.(csAbsorbers{iSubstance})) = true;


    % Initializing the data fields we want to fill
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_A0 = zeros(1,this.iSubstances);
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_B0 = zeros(1,this.iSubstances);
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_E  = zeros(1,this.iSubstances);
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_T0 = zeros(1,this.iSubstances);
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_C0 = zeros(1,this.iSubstances);
    
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.mfAbsorptionEnthalpy = zeros(1,this.iSubstances);
    
    % Due to the nature of the constant class, we need to store all of the
    % information for each substance in a single struct. We now need to
    % parse the information in this struct into the matter table format. 
    
    % First we get the struct for the current substance.
    tData = matter.data.AbsorberData.(csAbsorbers{iSubstance});
    
    % Parsing the Toth parameters for CO2 absorption
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_A0(this.tiN2I.CO2) = tData.tToth.fA0_CO2;
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_B0(this.tiN2I.CO2) = tData.tToth.fB0_CO2;
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_E(this.tiN2I.CO2)  = tData.tToth.fE_CO2;
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_T0(this.tiN2I.CO2) = tData.tToth.fT0_CO2;
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_C0(this.tiN2I.CO2) = tData.tToth.fC0_CO2;
    
    % Parsing the Toth parameters for H2O absorption
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_A0(this.tiN2I.H2O) = tData.tToth.fA0_H2O;
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_B0(this.tiN2I.H2O) = tData.tToth.fB0_H2O;
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_E(this.tiN2I.H2O)  = tData.tToth.fE_H2O;
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_T0(this.tiN2I.H2O) = tData.tToth.fT0_H2O;
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.tToth.mf_C0(this.tiN2I.H2O) = tData.tToth.fC0_H2O;
    
    % Parsing the absorption enthalpy
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.CO2) = tData.fAdsorptionEnthalpy_CO2;
    this.ttxMatter.(csAbsorbers{iSubstance}).tAbsorberParameters.mfAbsorptionEnthalpy(this.tiN2I.H2O) = tData.fAdsorptionEnthalpy_H2O;

end




end

