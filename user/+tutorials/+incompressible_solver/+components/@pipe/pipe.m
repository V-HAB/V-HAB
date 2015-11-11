classdef pipe < matter.procs.f2f
    %PIPE Summary of this class goes here
    %   Detailed explanation goes here

    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Properties -------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (Constant = true)

        % For reynolds number calculation
        Const = struct(...
            'fReynoldsCritical', 2320 ...
        );

    end

    properties (SetAccess = public, GetAccess = public)
        % Length, diameter in [m]
        fLength   = 0;
        fDiameter = 0;
    end

    properties (SetAccess = protected, GetAccess = public)
        % Surface roughness of the pipe in [?]
        fRoughness      = 0;
        fDeltaPressure = 0;

    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = pipe(oMT, sName, fLength, fDiameter, fRoughness)

            this@matter.procs.f2f(oMT, sName);

            this.fLength   = fLength;
            this.fDiameter = fDiameter;
            
            this.supportSolver('hydraulic', fDiameter, fLength);
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
            

            if nargin == 5
               this.fRoughness = fRoughness;
            end

        end
        
        %% Update function for hydraulic solver
        function update(this)

            bZeroFlows = 0;
            for k = 1:length(this.aoFlows)
                if this.aoFlows(1,k).fFlowRate == 0
                   bZeroFlows = 1;
                end
            end

            if bZeroFlows == 0
                [oFlowIn, ~ ]=this.getFlows();

                fDensity = this.oMT.calculateDensity(oFlowIn);

                fDynamicViscosity = this.oMT.calculateDynamicViscosity(oFlowIn);

                fFlowSpeed = abs(oFlowIn.fFlowRate/(fDensity*pi*0.25*this.fDiameter^2));

                this.fDeltaPressure = pressure_loss_pipe(this.fDiameter, this.fLength,...
                                fFlowSpeed, fDynamicViscosity, fDensity, this.fRoughness, 0);
            end

        end
        
        %% Update function for callback solver
        function fDeltaPress = solverDeltas(this, fFlowRate, fDensity, fDynamicViscosity)
            
            if nargin == 2
                
                for k = 1:length(this.aoFlows)
                    if fFlowRate == 0
                       fDeltaPress = 0;
                       return
                    end
                end
                try
                     [oFlowIn, ~ ]=this.getFlows();

                    fDensity = this.oMT.calculateDensity(oFlowIn);

                    fDynamicViscosity = this.oMT.calculateDynamicViscosity(oFlowIn);

                catch
                    fDensity = 1;
                    fDynamicViscosity = 1e-6;
                end
                fFlowSpeed = abs(fFlowRate/(fDensity*pi*0.25*this.fDiameter^2));

                fDeltaPress = pressure_loss_pipe(this.fDiameter, this.fLength,...
                                fFlowSpeed, fDynamicViscosity, fDensity, this.fRoughness, 0);
            else
                
                fFlowSpeed = abs(fFlowRate/(fDensity*pi*0.25*this.fDiameter^2));

                fDeltaPress = pressure_loss_pipe(this.fDiameter, this.fLength,...
                                fFlowSpeed, fDynamicViscosity, fDensity, this.fRoughness, 0);
            end

        end

    end

end
