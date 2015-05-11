classdef Transformer < matter.store
    %REACTOR Example of a reactor for V-HAB 2.0 including a manipulator
    %   Creates two phases, one for the flow throuhg the reactor, one for 
    %   the connected absorber. A manipulating processor is connected to
    %   the flow phase and converts CO2 to C and O2. A phase to phase
    %   processor (p2p) connects the two phases and transfers the remaining
    %   carbon in to the absorber phase. 
    
    properties (SetAccess = protected, GetAccess = public)
    end
    
    methods
        function this = Transformer(oMT, sName)
            % Create a geometry object, here its a cylinder 0.25 m in
            % diameter and 0.3 m high.
            oGeo = geom.volumes.cylinder(0.5, 0.4);
            
            this@matter.store(oMT, sName, oGeo.fVolume);
            
            % Creating two phases, on for the flow, one for the filter
            oFlowPhase     = this.createPhase('air', 'FlowPhase',     oGeo.fVolume);
            
            % Create the according exmes
            % In- and Outlet for the flow phase
            matter.procs.exmes.gas(oFlowPhase,     'Inlet');
            matter.procs.exmes.gas(oFlowPhase,     'Outlet');
            
            
            % Creating the manipulator
            tutorials.manipulator_test.components.DummyBoschProcess('DummyBoschProcess', oFlowPhase);
            
        end
    end    
end

