classdef SeparatorStore < matter.store
    %Initializes a store with two phases, 'Air' and 'SeparatedWaterPhase'.
    % In addition a processor is defined that absorbs all water in the 'air' phase and further it to the 'SeparatedWaterPhase' 
    properties (SetAccess = protected, GetAccess = public)
        fVol;
        oProc;
        oParent
    end
    
    methods
        function this = SeparatorStore(oParent, sName)
            this@matter.store(oParent, sName, 1);
            
              %Forwarding parameters
                this.fVol = 1;
                this.oParent = oParent;
    
            
            %Water separator's 'air'-phase
               oFlow = this.createPhase('air', ...                                        %Phase content
                                    this.fVol, ...                                        %Phase volume
                                    292.65, ...                                           %Phase temperature
                                    0);                                                   %Phase (air) humidity
          
          
          
            %Water Separator 'SeparatedWater'-phase
                oSeparatedWater = matter.phases.gas(this, ...
                                    'H2O',...
                                    struct(),...
                                    this.fVol/10,...                                      %Phase volume
                                    293.15);                                              %Phase temperature
            %Interfaces
                %Regarding Greenhouse
                    matter.procs.exmes.gas(oFlow, 'FromGreenhouse');
                    matter.procs.exmes.gas(oFlow, 'ToGreenhouse');
                %Regarding Absorber
                    matter.procs.exmes.gas(oFlow, 'SeparatorPort');
                    matter.procs.exmes.gas(oSeparatedWater, 'SeparatorPort');
           
            %Initializing Water Absorber
                this.oProc = tutorials.plant_module.components.WaterSeparator.WaterAbsorber(this.oParent, this, 'SeparatorProc', [this.sName,'_Phase_1.SeparatorPort'], 'H2O.SeparatorPort', 'H2O');
            
        end
                    
    end
    
    methods (Access = protected)
        function setVolume(this, ~)
            this.aoPhases(1).setVolume(this.fVol);
            this.aoPhases(2).setVolume(this.fVol/10);
        end
    end
        
end
