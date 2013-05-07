classdef split < matter.store
    %STORE Virtual store to split matter streams
    %   Detailed explanation goes here
    %
    %TODO
    %   - volume depending on flow rate ?
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    
    
    methods
        function this = split(oMT, sName)
            %TODO don't inherit from store, need to behave more like a flow
            %     anyway ...
            
            this@matter.store(oMT, sName, 1);
        end
        
        function update(this)
            %TODO Calc and set volume based on flow rates at the exme procs
            %     Also calc vector containing relative pressure drops which
            %     is used to calculate different pressures for each port.
            
            update@matter.store(this);
        end
    end
    
    
    %% Methods for the outer interface - manage ports, volume, ...
    methods
        function setVolume(this, fVolume)
            %TODO set some kind of dampening value instead?
        end
        
        function this = addPhase(this, oPhase)
            %TODO allow only one phase to be added? Add phase in
            %     constructor here? Multiple flows should be done through
            %     parallel, linked flows/procs? Special handling of fluids,
            %     pressure etc ...
        end
    end
    
    
    
    %% Internal methods for handling of table, phases, f2f procs %%%%%%%%%%
    methods (Access = protected)
        
    end
    
end

