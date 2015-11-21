classdef water_absorber < matter.store
    %FILTER Generic filter model
    %   This filter is modeled as a store with two phases, one representing
    %   the flow volume, the other representing the volume taken up by the
    %   material absorbing matter from the gas stream through the flow
    %   volume. 
    %   The two phases are connected by a phase-to-phase (p2p) processor.
    
    %TODO
    %   - Air phase - initial values should be adjustable, rename to flow
    %   - Prevent adding of phases (not with seal, can't connect flow)
    %   - EXME could implement some functionality as manipulate (provide
    %     other arPartialMass for outflowing), or provide different
    %     pressures for in- and outflowing? Or do that with two separate
    %     EXMEs?
    
    properties (SetAccess = protected, GetAccess = public)
        oGeometry;
        oProc;
    end
    
    methods
        function this = water_absorber(oMT, sName, fCapacity)
            % Creating a geometry object using the geometry framework and
            % the cylinder function. First input parameter is the diameter,
            % second is height. 
            %TODO fCapacity would normally probably depend on the type of
            %     the absorber material and the volume of the filter ...?
            oGeo = geometry.volumes.cylinder(0.25, 0.3);
            
            % Creating a store based on the cylinder's volume
            this@matter.store(oMT, sName, 5.1);
            
            % Assigning the filter's property
            % Set for later reference - see below, setVolume
            this.oGeometry = oGeo;
            
            % Creating the phase representing the flow volume, using the
            % 'air' helper and half of the cylinder volume as input
            %oFlow = this.createPhase('air', 2, 293.15,0.5);
             oFlow = matter.phases.gas(this, ...
                'air', ... Phase name
                struct('O2',21.49/80*5,'N2',70.35/80*5,'CO2',0.09/80*5,'H2O', 0.01), ... Phase contents - set by helper
                5, ... Phase volume
                293.15); % Phase temperature ;
            
            % Creating the phase representing the absorber volume manually.
            % The phase is empty and uses the other half of the filter
            % volume.
            oFiltered = matter.phases.liquid(this, ...
                          'absorbed_water', ... Phase name
                          struct('H2O', 0.1), ... Phase contents
                          0.1, ... Phase volume
                          293.15); % Phase temperature 
            
            % Create the according exmes - default for the external
            % connections, i.e. the air stream that should be filtered. The
            % filterports are internal ones for the p2p processor to use.
            matter.procs.exmes.gas(oFlow,     'p1');
            matter.procs.exmes.gas(oFlow,     'p2');
            matter.procs.exmes.liquid(oFiltered, 'p3');
            matter.procs.exmes.liquid(oFiltered, 'p4');
            matter.procs.exmes.gas(oFlow, 'p5');
            
            % Creating the p2p processor
            % Input parameters: name, flow phase name, absorber phase name, 
            % species to be filtered, filter capacity
            this.oProc = hami.BIO_LSS.components.absorber(this, 'filterproc', 'air.p2', 'absorbed_water.p3', 'H2O', fCapacity);
            
        end
    end

    methods (Access = protected)
        function setVolume(this, ~)
            % Overwriting the matter.store setVolume which would give both
            % gas phases the full volume. Could be adapted to include the
            % porosity or something from the absorber.
            this.aoPhases(1).setVolume(this.oGeometry.fVolume / 2);
            this.aoPhases(2).setVolume(this.oGeometry.fVolume / 2);
        end
    end
end