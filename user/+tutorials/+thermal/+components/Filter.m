classdef Filter < matter.store
    %FILTER Generic filter model
    %   This filter is modeled as a store with two phases, one representing
    %   the flow volume, the other representing the volume taken up by the
    %   material absorbing matter from the gas stream through the flow
    %   volume. 
    %   The two phases are connected by a phase-to-phase (p2p) processor.
     
    properties (SetAccess = protected, GetAccess = public)
        
        % We want to log the flow rate through the p2p processor, currently
        % the only way to access the processor is by setting it as a
        % property of this store. 
        oProc;
        
    end
    
    methods
        function this = Filter(oContainer, sName, fCapacity)
            % Creating a store based with a volume of 0.02 m^2
            this@matter.store(oContainer, sName, 0.025);
            
            % Creating the phase representing the flow volume, using the
            % 'air' helper. The phase volume will later be set to 0.01 m^2,
            % see method setVolume() below. To make the simulation start up
            % a bit faster, we'll set the phase pressure to a value that is
            % in between the two tanks on the system level. 
            oFlow = this.createPhase('air', 'FlowPhase', 0.015, 293.15);
            
            % Creating the phase representing the absorber volume manually.
            % Again, to make the simulation start up a bit faster, we
            % include a small amount of matter right from the start, rather
            % than setting the mass to exactly zero. 
            oFiltered = matter.phases.gas(this, ...
                          'FilteredPhase', ... Phase name
                          struct('O2',0.0001), ... Phase contents
                          0.01, ... Phase volume
                          293.15); % Phase temperature 
            
            % Create the according exmes - default for the external
            % connections, i.e. the air stream that should be filtered. The
            % filterports are internal ones for the p2p processor to use.
            matter.procs.exmes.gas(oFlow,     'FilterIn');
            matter.procs.exmes.gas(oFlow,     'FilterOut');
            
            % Creating the p2p processor
            % Input parameters: name, flow phase name, absorber phase name, 
            % species to be filtered, filter capacity
            this.oProc = tutorials.thermal.components.AbsorberExample(this, 'filterproc', 'FlowPhase', 'FilteredPhase', 'O2', fCapacity);
            
        end
    end
end