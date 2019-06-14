classdef incompressibleMedium < matter.manips.volume.stationary
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    methods
        function this = incompressibleMedium(sName, oPhase)
            this@matter.manips.volume.stationary(sName, oPhase);
            
            % bind the update function to the update of the connected
            % phase, as an update signifies a sufficiently large change in
            % mass of the incompressible phase to necessitate a volume
            % recalculation
        end
        
        function update(this, ~)
            
            update@matter.manips.volume.stationary(fVolume, fPressure);
            
            this.fLastExec = this.oTimer.fTime;
        end
    end
end