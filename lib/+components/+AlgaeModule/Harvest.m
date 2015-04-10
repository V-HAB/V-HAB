classdef Harvest < vsys
    %EXAMPLESUBSYSTEM A subsystem containing a filter and a pipe
    %   This example shows a vsys child representing a subsystem of a larger system. It has a Filter
    %   which removes O2 from the mass flow through the subsystem and it provides the neccessary
    %   setIfFlows function so the subsystem branches can be connected to the system level branches.
    %   The pipe is only added for demonstration purposes.
    
    properties
        fMass_Algae;
        fVolume_FreshWater;
        fHarvest = 0;
        fDilution;
    end
    
    methods
        function this = Harvest(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            
            this.calculateDilution();
        end
            %function not yet implemented
           function calculateDilution(this)
            
            this.fMass_Algae = this.oParent.toStores.Filter_Algae_Reactor.aoPhases(2).fMass; 
            this.fVolume_FreshWater = this.oParent.toStores.Filter_Algae_Reactor.oGeometry.fVolume;
            
            this.fDilution = this.fMass_Algae / this.fVolume_FreshWater;
            
            this.oParent.toChildren.Harvest.fDilution;
            this.oParent.toChildren.Harvest.fDilution = this.fDilution;
            this.oParent.fDilution = this.fDilution;
            
            if this.fDilution >= 0.01
                this.fHarvest = 1; %on
                
             elseif this.fDilution < 0.001
                 this.fHarvest = 0; %off
            end
            
           
            
            
        

          
                
           end
           

        end
    
            
        

    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            %this.toStores.Filter.aoPhases(2).update(this.fTimeStep);
            %this.toStores.Filter.oProc.update();
        end
    end
end

     








