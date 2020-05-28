classdef thermalObserver < simulation.monitor
    %THERMALOBSERVER Dummy observer (for now)
    
    properties
    end
    
    
    methods
        function this = thermalObserver(oSimulationInfrastructure)
            this@simulation.monitor(oSimulationInfrastructure, { 'init_post' });
            
        end
    end
    
    
    methods (Access = protected)
        
        function onInitPost(this, ~)
            
            toChildren = this.oSimulationInfrastructure.oSimulationContainer.toChildren;
            sChild = this.oSimulationInfrastructure.oSimulationContainer.csChildren{1};
            oChild = toChildren.(sChild);
            
            [ iCapacities, iThermalBranches ] = this.countCapacitiesAndBranches(oChild);
            
            if iThermalBranches == 1; sEnding1 = ''; else; sEnding1 = 'es'; end
            if iCapacities == 1; sEnding2 = 'y'; else; sEnding2 = 'ies'; end
            fprintf('Model contains %i Thermal Branch%s and %i Capacit%s.\n', iThermalBranches, sEnding1, iCapacities, sEnding2);
            
            
        end
        
        function [iCapacitiesOut, iBranchesOut] = countCapacitiesAndBranches(this, oSystem, iCapacitiesIn, iBranchesIn)
            
            iChildCapacities = 0;
            iChildBranches   = 0;
            
            if nargin < 3
                iCapacitiesIn = 0;
                iBranchesIn   = 0;
            end
            
            for iChild = 1:oSystem.iChildren
                [iChildCapacities, iChildBranches] = this.countCapacitiesAndBranches(oSystem.toChildren.(oSystem.csChildren{iChild}), iChildCapacities, iChildBranches);
            end
            
            iCapacitiesOut = oSystem.iCapacities + iChildCapacities + iCapacitiesIn;
            iBranchesOut   = oSystem.iThermalBranches + iChildBranches + iBranchesIn;
            
            
        end
    end
end

