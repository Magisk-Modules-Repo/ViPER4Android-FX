# This script will be executed in late_start service mode
# More info in the main Magisk thread
(
sleep 3

magiskpolicy --live 'allow audioserver audioserver_tmpfs file { read write execute }'
magiskpolicy --live 'allow audioserver system_file file { execmod }'
magiskpolicy --live 'allow mediaserver mediaserver_tmpfs file { read write execute }'
magiskpolicy --live 'allow mediaserver system_file file { execmod }'
magiskpolicy --live 'allow audioserver unlabeled file { read write execute open getattr }'
magiskpolicy --live 'allow hal_audio_default hal_audio_default process { execmem }'
magiskpolicy --live 'allow hal_audio_default hal_audio_default_tmpfs file { execute }'
magiskpolicy --live 'allow hal_audio_default audio_data_file dir { search }'
magiskpolicy --live 'allow app app_data_file file { execute_no_trans }'
magiskpolicy --live 'allow mtk_hal_audio mtk_hal_audio_tmpfs file { execute }'

killall -q audioserver
killall -q mediaserver
)&
