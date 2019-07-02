%This script is used to launch the data fitting process.

clear
clc
format long

% Set the initial parameter set for the fitting
x0 = suyi.CROP.validation.Para_Initial_in_Fitting();

% The residual function for the fitting
fun=@(x)suyi.CROP.validation.Residual_Fun(x);

% Fitting options for the solver "lsqnonlin" from the MATLAB Toolbox using
% the Levenberg-Marquardt Method as optimization algorithm
options = optimoptions('lsqnonlin','Display','iter');
options.Algorithm = 'levenberg-marquardt';
options = optimoptions(options,'StepTolerance',1e-2);
options = optimoptions(@lsqnonlin,'OutputFcn', @outfun);

% Launch the data fitting process with the solver "lsqnonlin"
[x,resnorm,residual,exitflag,output] = lsqnonlin(fun,x0,[],[],options);

