 classdef PowerControl < vsys
    %EXAMPLESUBSYSTEM A subsystem containing a filter and a pipe
    %   This example shows a vsys child representing a subsystem of a larger system. It has a Filter
    %   which removes O2 from the mass flow through the subsystem and it provides the neccessary
    %   setIfFlows function so the subsystem branches can be connected to the system level branches.
    %   The pipe is only added for demonstration purposes.
    
    properties
        fPower = 2400;
        fAerationPower = 0;
    end
    
    methods
        function this = PowerControl(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            
      %this.oParent.toChildren.PowerControl.fPower
      
      %needs to be completely implemented so the power is settable from
      %the vhab environment
      
      
      
        end 
            function getPower(this, fPower)  
                
                this.fPower = fPower;
           end
    end
 end

 









