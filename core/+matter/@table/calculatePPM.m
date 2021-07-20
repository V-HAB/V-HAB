function [ afPPM ] = calculatePPM(this, afMass)
% This function can be used to calculate the concentration of substances in
% parts per million (PPM) based on the following input:
%
% afMass: Vector containing the total partial masses of each substance in kg

afMols = afMass ./ this.afMolarMass;

afPPM = (afMols ./ sum(afMols)) * 10^6;
end