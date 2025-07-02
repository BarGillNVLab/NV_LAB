function main()
Setup.init;
spcm = getObjByName(Spcm.NAME);
iscamera = spcm.hasCamera;
GuiControllerImage(iscamera).start;
end