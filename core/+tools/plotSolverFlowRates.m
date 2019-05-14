%PLOTSOLVERFLOWRATES Plots flow rates for all iterations in multi-branch solver
% In case the multi-branch solver aborted due to exceeding the maximum
% number of iterations allowed, it will stop using the keyboard() command.
% When in this state, use this script to create a nice plot of the flow
% rates including a legend, labels, etc. 

plot(mfFlowRates);
title('Multi-Branch Solver Flow Rates')
legend({this.aoBranches.sName}, 'interpreter', 'none');
ylabel('Flow Rate [kg/s]');
xlabel('Iteration');

oButton = uicontrol(gcf,'String','Save','FontSize',10,'Position',[ 0 0 50 30]);
oButton.Callback = @tools.postprocessing.plotter.helper.saveFigureAs;
