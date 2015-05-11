classdef Reactor < matter.store
    %REACTOR Example of a reactor for V-HAB 2.0 including a manipulator
    %   Creates two phases, one for the flow throuhg the reactor, one for 
    %   the connected absorber. A manipulating processor is connected to
    %   the flow phase and converts CO2 to C and O2. A phase to phase
    %   processor (p2p) connects the two phases and transfers the remaining
    %   carbon in to the absorber phase. 
    
    properties (SetAccess = protected, GetAccess = public)
%         oGeometry;
         oProc;
    end
    
    methods
        function this = Reactor(oMT, sName)
            % Create a geometry object, here its a cylinder 0.25 m in
            % diameter and 0.3 m high.
            oGeo = geom.volumes.cylinder(0.25, 0.3);
            
            this@matter.store(oMT, sName, oGeo.fVolume);
            
            % Set for later reference - see below, setVolume
%            this.oGeometry = oGeo;
            
            % Creating two phases, on for the flow, one for the filter
            oFlowPhase     = this.createPhase('air', 'FlowPhase',     oGeo.fVolume);
            oFilteredPhase = this.createPhase('air', 'FilteredPhase', oGeo.fVolume);
            
            
            
            % Create the according exmes
            % In- and Outlet for the flow phase
            matter.procs.exmes.gas(oFlowPhase,     'Inlet');
            matter.procs.exmes.gas(oFlowPhase,     'Outlet');
            % Each phase gets one exme for connection to the p2p proc. 
            matter.procs.exmes.gas(oFlowPhase,     'FilterPort');
            matter.procs.exmes.gas(oFilteredPhase, 'FilterPort');
            
            
            % Creating the manipulator
            tutorials.manipulator.components.DummyBoschProcess('DummyBoschProcess', oFlowPhase);
            
            % Createing the p2p processor.
            % Parameter: name, from, to, substance, capacity
            this.oProc = tutorials.manipulator.components.AbsorberExample(this, 'FilterProc', 'FlowPhase.FilterPort', 'FilteredPhase.FilterPort', 'C', inf);
        end
    end    
end

