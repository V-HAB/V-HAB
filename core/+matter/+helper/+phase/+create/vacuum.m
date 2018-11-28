function [ cParams, sDefaultPhase ] = vacuum(varargin)
%VACUUM helper to create a vacuum matter phase

% Create cParams for a whole matter.phases.gas standard phase. Since the
% vacuum is empty, the mass struct is empty as well. The volume is
% infinite, the temperature is equal to the cosmic background of 3 K and
% the pressure is zero. 
cParams = { struct() Inf 3 0};

% Returning the phase constructor path that the parameters are to be used
% on. 
sDefaultPhase = 'matter.phases.boundary.gas';

end
