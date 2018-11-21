function SEAR_plots(oVHABSim)
% Special function that will alter the old sim object after the fact to
% produce the desired plots. Can be removed, if no longer needed.

csSEAR_Names      = {'SEAR_Back','SEAR_Top','SEAR_Bottom','SEAR_Left','SEAR_Right'};
csSEAR_Plot_Names = {'SEAR Back','SEAR Top','SEAR Bottom','SEAR Left','SEAR Right'};

csLogValues = {...
    'FlowRatesSWMEOut',...
    'FlowRatesIVVOut',...
    'FlowRatesLCARIn',...
    'FlowRatesLCAROut',...
    'MassesAbsorberPhase',...
    'AbsorptionRatesActual',...
    'AbsorptionRatesComputed',...
    'AbsorbentMassFraction',...
    'VaporPressure',...
    'TemperaturesRadiator',...
    'TemperaturesAbsorber',...
    'EquilibriumEquilibrium',...
    'EquilibriumActual',...
    'RadPowerRadiator',...
    'RadPowerAbsorber',...
    'RadFlowSWME',...
    'PowerRatio'};


tiLog = struct();

afIndexes = 670:754;

for iI = 1:length(csSEAR_Names)
    for iJ = 1:length(csLogValues)
        tiLog.(csLogValues{iJ}).(csSEAR_Names{iI}) = afIndexes(1 + (iI-1) * 17 + (iJ-1));
        oVHABSim.toMonitors.oLogger.tLogValues(afIndexes(1 + (iI-1) * 17 + (iJ-1))).sLabel = [csSEAR_Plot_Names{iI},' - ',oVHABSim.toMonitors.oLogger.tLogValues(afIndexes(1 + (iI-1) * 17 + (iJ-1))).sLabel];
    end
end

for iI = 1:length(csSEAR_Names)
%     tiLog.Temperatures.([csSEAR_Names{iI},'_',csLogValues{10}]) = tiLog.(csLogValues{10}).(csSEAR_Names{iI});
%     tiLog.Temperatures.([csSEAR_Names{iI},'_',csLogValues{11}]) = tiLog.(csLogValues{11}).(csSEAR_Names{iI});
    
    tiLog.Equilibrium.([csSEAR_Names{iI},'_',csLogValues{12}]) = tiLog.(csLogValues{12}).(csSEAR_Names{iI});
    tiLog.Equilibrium.([csSEAR_Names{iI},'_',csLogValues{13}]) = tiLog.(csLogValues{13}).(csSEAR_Names{iI});
end

% oVHABSim.toMonitors.oPlotter.definePlot(tiLog.FlowRatesSWMEOut, 'Flow Rates SWME Out');
% oVHABSim.toMonitors.oPlotter.definePlot(tiLog.FlowRatesIVVOut, 'Flow Rates IVV Out');
oVHABSim.toMonitors.oPlotter.definePlot(tiLog.FlowRatesLCARIn, 'Flow Rates LCAR In');
% oVHABSim.toMonitors.oPlotter.definePlot(tiLog.FlowRatesLCAROut, 'Flow Rates LCAR Out');
oVHABSim.toMonitors.oPlotter.definePlot(tiLog.MassesAbsorberPhase, 'Tank Masses');
oVHABSim.toMonitors.oPlotter.definePlot(tiLog.AbsorptionRatesActual, 'Act. Abs. Rate');
oVHABSim.toMonitors.oPlotter.definePlot(tiLog.AbsorptionRatesComputed, 'Calc Abs. Rate');
oVHABSim.toMonitors.oPlotter.definePlot(tiLog.AbsorbentMassFraction, 'Absorbent Mass Fraction');
oVHABSim.toMonitors.oPlotter.definePlot(tiLog.VaporPressure, 'Vapor pressure at phase boundary');
oVHABSim.toMonitors.oPlotter.definePlot(tiLog.TemperaturesRadiator, 'Radiator Temperatures');
oVHABSim.toMonitors.oPlotter.definePlot(tiLog.Equilibrium, 'Equilibrium State');
oVHABSim.toMonitors.oPlotter.definePlot(tiLog.RadFlowSWME, 'Radiated Heat Flow');

oVHABSim.toMonitors.oPlotter.plot(struct('bTimePlotOn',false,'bLegendOn',false));

end


