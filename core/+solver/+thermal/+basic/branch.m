classdef branch < solver.thermal.base.branch
% A basic thermal solver which calculates the heat flow through a thermal
% branch based on the temperature difference between the adjacent phases
% and the conductor values. Please note that the conductors in the branch
% are assumed to be in a row between the two capacities, if you want to
% model a parallel heat transfer use multiple branches!
    
    properties (SetAccess = private, GetAccess = public)
        
        % Actual time between flow rate calculations
        fTimeStep = inf;
        
        fSolverHeatFlow = 0;
        
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.thermal.base.branch(oBranch, 'basic');
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed
            this.hBindPostTickUpdate      = this.oBranch.oTimer.registerPostTick(@this.update, 'thermal' , 'solver');
            
            this.update();
        end
        
    end
    
    methods (Access = protected)
        function update(this)
            
            afConductivity              = zeros(1,this.oBranch.iConductors);
            bRadiative      = false;
            bConductive     = false;
            
            for iConductor = 1:this.oBranch.iConductors
                this.oBranch.coConductors{iConductor}.update();
                if this.oBranch.coConductors{iConductor}.bRadiative
                    bRadiative = true;
                else
                    bConductive= true;
                end
                afConductivity(iConductor) = this.oBranch.coConductors{iConductor}.fConductivity;
            end
            
            if bRadiative && bConductive
                this.throw('branch', 'Basic thermal solver cannot calculate conductive/convective and radiative heat transfer at the same time, please use two different branches or use a different solver');
            end
            
            if bConductive
                fDeltaTemperature = this.oBranch.coExmes{1}.oCapacity.fTemperature - this.oBranch.coExmes{2}.oCapacity.fTemperature;
            
            else
                fDeltaTemperature = this.oBranch.coExmes{1}.oCapacity.fTemperature^4 - this.oBranch.coExmes{2}.oCapacity.fTemperature^4;
            
            end
            
            afThermalResistance = 1./afConductivity;

            % See Wärmeübetragung Polifke equation 3.16, only valid if
            % all resistances are in a row and not parallel, for
            % parallel resistances use multiple branches
            fTotalThermalResistance = sum(afThermalResistance);

            this.fSolverHeatFlow = fDeltaTemperature / fTotalThermalResistance;
            
            this.oBranch.coExmes{1}.setHeatFlow(this.fSolverHeatFlow);
            this.oBranch.coExmes{2}.setHeatFlow(this.fSolverHeatFlow);
            
            % the temperatures between the conductors are not required, but
            % it is possible to define a different thermal branch that
            % calculates them, e.g. to calculate the wall temperature in a
            % heat exchanger
            afTemperatures = []; 
            update@solver.thermal.base.branch(this, this.fSolverHeatFlow, afTemperatures);
            
        end
    end
end
