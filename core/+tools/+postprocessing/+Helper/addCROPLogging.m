function addCROPLogging(oLogger, oSystem)
%% CROP Logs
csUrineInFlowRates              = cell(1, oSystem.iCROPs);
csWaterInFlowRates              = cell(1, oSystem.iCROPs);
csUreaInFlowRates               = cell(1, oSystem.iCROPs);
csWaterOutFlowRates             = cell(1, oSystem.iCROPs);
csUreaOutFlowRates              = cell(1, oSystem.iCROPs);
csNO3OutFlowRates               = cell(1, oSystem.iCROPs);
csNH4OutFlowRates               = cell(1, oSystem.iCROPs);

for iCrop = 1:oSystem.iCROPs
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toBranches.CROP_Urine_Inlet.aoFlows(1)'],         'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Urine)',     'kg/s', ['Urine to CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toPhases.TankSolution.toManips.substance'],         'this.afPartialFlows(this.oMT.tiN2I.H2O)',     'kg/s', ['H2O to CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toPhases.TankSolution.toManips.substance'],         'this.afPartialFlows(this.oMT.tiN2I.CH4N2O)',  'kg/s', ['Urea to CROP ', num2str(iCrop)]);

    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toBranches.CROP_Solution_Outlet.aoFlows(1)'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',      'kg/s', ['H2O from CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toBranches.CROP_Solution_Outlet.aoFlows(1)'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CH4N2O)',   'kg/s', ['Urea from CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toBranches.CROP_Solution_Outlet.aoFlows(1)'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.NO3)',      'kg/s', ['NO3 from CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toBranches.CROP_Solution_Outlet.aoFlows(1)'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.NH4)',      'kg/s', ['NH4 from CROP ', num2str(iCrop)]);

    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toProcsP2P.CO2_Outgassing_Tank'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s', ['CO2 from CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toProcsP2P.O2_to_TankSolution'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s', ['O2 to CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toProcsP2P.NH3_Outgassing_Tank'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.NH3)',      'kg/s', ['NH3 from CROP ', num2str(iCrop)]);

    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toPhases.TankSolution'],    	'this.afMass(this.oMT.tiN2I.H2O)',      'kg', ['H2O in CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toPhases.TankSolution'],    	'this.afMass(this.oMT.tiN2I.CH4N2O)',   'kg', ['Urea in CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toPhases.TankSolution'],    	'this.afMass(this.oMT.tiN2I.NO3)',      'kg', ['NO3 in CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toPhases.TankSolution'],    	'this.afMass(this.oMT.tiN2I.NH4)',      'kg', ['NH4 in CROP ', num2str(iCrop)]);
    oLogger.addValue([oSystem.sName, '.toChildren.CROP_', num2str(iCrop),'.toStores.CROP_Tank.toPhases.TankSolution'],    	'this.afMass(this.oMT.tiN2I.Urine)',    'kg', ['Urine in CROP ', num2str(iCrop)]);

    csUrineInFlowRates{iCrop} 	= ['"Urine to CROP ',       num2str(iCrop),'" +'];
    csWaterInFlowRates{iCrop} 	= ['"H2O to CROP ',         num2str(iCrop),'" +'];
    csUreaInFlowRates{iCrop}  	= ['"Urea to CROP ',        num2str(iCrop),'" +'];
    csWaterOutFlowRates{iCrop}	= ['"H2O from CROP ',       num2str(iCrop),'" +'];
    csUreaOutFlowRates{iCrop} 	= ['"Urea from CROP ',      num2str(iCrop),'" +'];
    csNO3OutFlowRates{iCrop}   	= ['"NO3 from CROP ',       num2str(iCrop),'" +'];
    csNH4OutFlowRates{iCrop}  	= ['"NH4 from CROP ',       num2str(iCrop),'" +'];

    csCO2OutFlowRates{iCrop}  	= ['"CO2 from CROP ',       num2str(iCrop),'" +'];
    csO2InFlowRates{iCrop}  	= ['"O2 to CROP ',          num2str(iCrop),'" +'];
    csNH3OutFlowRates{iCrop}  	= ['"NH3 from CROP ',       num2str(iCrop),'" +'];
end
sFlowRates = strjoin(csUrineInFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'Urine to CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Urine to CROP Mass');

sFlowRates = strjoin(csWaterInFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'Water to CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Water to CROP Mass');

sFlowRates = strjoin(csUreaInFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'Urea to CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Urea to CROP Mass');

sFlowRates = strjoin(csWaterOutFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'Water from CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Water from CROP Mass');

sFlowRates = strjoin(csUreaOutFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'Urea from CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Urea from CROP Mass');

sFlowRates = strjoin(csNO3OutFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'NO3 from CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'NO3 from CROP Mass');

sFlowRates = strjoin(csNH4OutFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'NH4 from CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'NH4 from CROP Mass');

sFlowRates = strjoin(csCO2OutFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'CO2 from CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'CO2 from CROP Mass');

sFlowRates = strjoin(csO2InFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'O2 to CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'O2 to CROP Mass');

sFlowRates = strjoin(csNH3OutFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'NH3 from CROP');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'NH3 from CROP Mass');

end