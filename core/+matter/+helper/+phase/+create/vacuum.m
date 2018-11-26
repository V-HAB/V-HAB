function [ cParams, sDefaultPhase ] = vacuum(varargin)
%VACUUM helper to create a vacuum matter phase

% Create cParams for a whole matter.phases.gas standard phase. If user does
% not want to use all of them, can just use
% matter.phases.gas(oMT.create('air'){1:2}, ...)
cParams = { struct() Inf 3 0};


% Default class - required for automatic construction of phase. Helper re-
% turns the default phase that could be constructed with this set of params
sDefaultPhase = 'matter.phases.boundary.gas';



end
