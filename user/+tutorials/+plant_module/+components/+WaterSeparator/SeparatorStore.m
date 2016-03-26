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
            this@matter.store(oParent, sName);
            
              %Forwarding parameters
                this.fVol = 1;
                this.oParent = oParent;
    
            
            %Water separator's 'air'-phase
               oFlow = this.createPhase('air', ...                                        %Phase content
                                    this.fVol, ...                                        %Phase volume
                                    292.65, ...                                           %Phase temperature
                                    0);                                                   %Phase (air) humidity
          
          
          
            %Water Separator 'SeparatedWater'-phase
                oSeparatedWater = matter.phases.liquid(this, ...
                                    'H2O',...
                                    struct('H2O', 1),...
                                    this.fVol/10,...                                      %Phase volume
                                    293.15, ...                                              %Phase temperature
                                    101325);
            %Interfaces
                %Regarding Greenhouse
                    matter.procs.exmes.gas(oFlow, 'FromGreenhouse');
                    matter.procs.exmes.gas(oFlow, 'ToGreenhouse');
                %Regarding Absorber
                    matter.procs.exmes.gas(oFlow, 'SeparatorPort');
                    matter.procs.exmes.liquid(oSeparatedWater, 'SeparatorPort');
           
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
