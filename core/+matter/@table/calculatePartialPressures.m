function [ output_args ] = calculateMols( input_args )
%CALCULATEMOLS Summary of this function goes here
%   Detailed explanation goes here
%TODO Implement this class...

%%%%% From flow.m:
function [ afPartialPressures ] = getPartialPressures(this)
            %TODO put in matter.table, see calcHeatCapacity etc (?)
            %     only works for gas -> store phase type in branch? Multi
            %     phase flows through "linked" branches? Or add "parallel"
            %     flows at each point in branch, one for each phase?
            
            % Calculating the number of mols for each species
            afMols = this.arPartialMass ./ this.oMT.afMolMass;
            % Calculating the total number of mols
            fGasAmount = sum(afMols);
            %fGasAmount = this.oMT.calculateMols(this);
            % Calculating the partial amount of each species by mols
            arFractions = afMols ./ fGasAmount;
            % Calculating the partial pressures by multiplying with the
            % total pressure in the phase
            afPartialPressures = arFractions .* this.fPressure;
        end


end

