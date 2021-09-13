function addCrewPlotting(oPlotter, oSystem, tPlotOptions)

csRespiratoryCoefficient = cell(1,6);
for iHuman = 1:(oSystem.iCrewMembers)
    csRespiratoryCoefficient{iHuman} = ['"Respiratory Coefficient ',    num2str(iHuman), '"'];
end

coPlot = cell(0);
coPlot{1,1} = oPlotter.definePlot({'"Effective CO_2 Flow Crew"', '"Effective O_2 Flow Crew"'},	'Crew Respiration Flowrates', tPlotOptions);
coPlot{1,2} = oPlotter.definePlot(csRespiratoryCoefficient,                                     'Crew Respiratory Coefficients', tPlotOptions);
coPlot{2,1} = oPlotter.definePlot({'"Exhaled CO_2"', '"Inhaled O_2"'},                          'Crew Cumulative Respiration', tPlotOptions);
coPlot{2,2} = oPlotter.definePlot({'"Respiration Water"', '"Perspiration Water"', '"Metabolism Water"', '"Urine Urea"'},    'Crew Cumulative Masses', tPlotOptions);

oPlotter.defineFigure(coPlot,       'Crew Values');

end