# Blood Reborn - janela do instalador único (carregada pelo BloodReborn.ps1). Estilo do BB Port: tema escuro, barra
# lateral, arte e fontes do próprio BB Port (_internal\assets), chaves vermelhas. Nomes: nenhum repete um parâmetro.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$XAML = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Blood Reborn" Width="1108" Height="728" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="CanMinimize" WindowStartupLocation="CenterScreen" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
    <SolidColorBrush x:Key="Texto" Color="#ECE5D8"/>
    <SolidColorBrush x:Key="Apagado" Color="#8F897E"/>
    <SolidColorBrush x:Key="Ouro" Color="#B99B6B"/>
    <LinearGradientBrush x:Key="Sangue" StartPoint="0,0" EndPoint="0,1">
      <GradientStop Color="#A8262C" Offset="0"/><GradientStop Color="#6A1115" Offset="1"/>
    </LinearGradientBrush>
    <Style x:Key="BotaoSangue" TargetType="Button">
      <Setter Property="Foreground" Value="#F6ECDF"/><Setter Property="FontSize" Value="17"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" CornerRadius="6" Background="{StaticResource Sangue}" BorderBrush="#C9474D" BorderThickness="1" Padding="32,11">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#FF7A80"/></Trigger>
          <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.85"/></Trigger>
          <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="BotaoEscuro" TargetType="Button">
      <Setter Property="Foreground" Value="#DDD6C9"/><Setter Property="FontSize" Value="13"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" CornerRadius="6" Background="#1A1A1E" BorderBrush="#34343B" BorderThickness="1" Padding="14,8">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#6A6A74"/><Setter TargetName="b" Property="Background" Value="#202025"/></Trigger>
          <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Janela" TargetType="Button">
      <Setter Property="Foreground" Value="#D8D1C4"/><Setter Property="FontFamily" Value="Segoe MDL2 Assets"/><Setter Property="FontSize" Value="10"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" CornerRadius="6" Background="#66000000" Width="34" Height="28" Margin="4,0,0,0">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#B0262C"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Nav" TargetType="Button">
      <Setter Property="Foreground" Value="#B9B3A8"/><Setter Property="FontSize" Value="14"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="fundo" CornerRadius="7" Background="Transparent" Padding="14,10" Margin="0,2">
          <Grid>
            <Border x:Name="barra" Width="3" HorizontalAlignment="Left" Margin="-14,-2,0,-2" CornerRadius="2" Background="#C4313A" Visibility="Collapsed"/>
            <ContentPresenter VerticalAlignment="Center"/>
          </Grid>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="fundo" Property="Background" Value="#141418"/></Trigger>
          <Trigger Property="Tag" Value="sel">
            <Setter TargetName="fundo" Property="Background" Value="#1C1A1E"/>
            <Setter TargetName="barra" Property="Visibility" Value="Visible"/>
            <Setter Property="Foreground" Value="#F4EDE0"/>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Pilula" TargetType="Button">
      <Setter Property="Foreground" Value="#A9A397"/><Setter Property="FontSize" Value="12"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" CornerRadius="12" Background="#141417" BorderBrush="#2C2C33" BorderThickness="1" Padding="10,4" Margin="0,0,6,6">
          <ContentPresenter HorizontalAlignment="Center"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#5A5A62"/></Trigger>
          <Trigger Property="Tag" Value="sel">
            <Setter TargetName="b" Property="BorderBrush" Value="#C4313A"/><Setter TargetName="b" Property="Background" Value="#2A1416"/>
            <Setter Property="Foreground" Value="#F4EDE0"/>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Chave" TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox">
        <Border x:Name="trilho" Width="44" Height="24" CornerRadius="12" Background="#26262C" BorderBrush="#3A3A42" BorderThickness="1">
          <Ellipse x:Name="bola" Width="18" Height="18" Fill="#BDB7AC" HorizontalAlignment="Left" Margin="2,0,0,0"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsChecked" Value="True">
            <Setter TargetName="trilho" Property="Background" Value="#A3262C"/><Setter TargetName="trilho" Property="BorderBrush" Value="#D2525A"/>
            <Setter TargetName="bola" Property="HorizontalAlignment" Value="Right"/><Setter TargetName="bola" Property="Margin" Value="0,0,2,0"/>
            <Setter TargetName="bola" Property="Fill" Value="#FFF5EA"/>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Caixa" TargetType="TextBox">
      <Setter Property="Foreground" Value="#ECE5D8"/><Setter Property="CaretBrush" Value="#ECE5D8"/><Setter Property="FontSize" Value="13"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TextBox">
        <Border x:Name="b" CornerRadius="7" Background="#121215" BorderBrush="#2C2C33" BorderThickness="1" Padding="10,7">
          <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#9A2C33"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="8"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
        <Track x:Name="PART_Track" IsDirectionReversed="True">
          <Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType="Thumb"><Border CornerRadius="4" Background="#34343B" Margin="1,0"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
        </Track>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
  </Window.Resources>

  <Border Margin="14" CornerRadius="12" Background="#0D0D10" BorderBrush="#3A1B1E" BorderThickness="1">
    <Border.Effect><DropShadowEffect BlurRadius="18" ShadowDepth="0" Opacity="0.75" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.ColumnDefinitions><ColumnDefinition Width="252"/><ColumnDefinition/></Grid.ColumnDefinitions>

      <!-- barra lateral -->
      <Border Grid.Column="0" CornerRadius="12,0,0,12" BorderBrush="#1D1D22" BorderThickness="0,0,1,0">
        <Border.Background>
          <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
            <GradientStop Color="#0B0B0E" Offset="0"/><GradientStop Color="#120A0C" Offset="1"/>
          </LinearGradientBrush>
        </Border.Background>
        <DockPanel Margin="18,20,18,16">
          <StackPanel DockPanel.Dock="Top">
            <StackPanel Orientation="Horizontal">
              <Image x:Name="Emblema" Width="50" Height="50" Margin="0,0,10,0" RenderOptions.BitmapScalingMode="HighQuality"/>
              <StackPanel VerticalAlignment="Center">
                <TextBlock x:Name="TituloApp" Text="BLOOD REBORN" FontSize="16" FontWeight="Bold" Foreground="{StaticResource Texto}"/>
                <TextBlock x:Name="SubApp" FontSize="11.5" Foreground="{StaticResource Apagado}" Margin="1,2,0,0"/>
              </StackPanel>
            </StackPanel>
            <Grid Margin="0,22,0,16">
              <TextBox x:Name="CaixaBusca" Style="{StaticResource Caixa}" Padding="22,0,0,0"/>
              <TextBlock Text="&#xE721;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#77716A" Margin="12,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
              <TextBlock x:Name="DicaBusca" FontSize="12.5" Foreground="#6F6A63" Margin="34,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
            </Grid>
            <Button x:Name="NavMods" Style="{StaticResource Nav}" Tag="sel">
              <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE7FC;" FontFamily="Segoe MDL2 Assets" Width="28" VerticalAlignment="Center"/><TextBlock x:Name="NavModsTxt"/></StackPanel>
            </Button>
            <Button x:Name="NavFix" Style="{StaticResource Nav}">
              <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE90F;" FontFamily="Segoe MDL2 Assets" Width="28" VerticalAlignment="Center"/><TextBlock x:Name="NavFixTxt"/></StackPanel>
            </Button>
            <Button x:Name="NavAjuda" Style="{StaticResource Nav}">
              <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE897;" FontFamily="Segoe MDL2 Assets" Width="28" VerticalAlignment="Center"/><TextBlock x:Name="NavAjudaTxt"/></StackPanel>
            </Button>
          </StackPanel>
          <StackPanel DockPanel.Dock="Bottom" VerticalAlignment="Bottom">
            <StackPanel Orientation="Horizontal" Margin="2,0,0,8">
              <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="{StaticResource Apagado}" Margin="0,2,8,0"/>
              <TextBlock x:Name="LblIdioma" FontSize="12" Foreground="{StaticResource Apagado}"/>
            </StackPanel>
            <WrapPanel>
              <Button x:Name="LingPT" Style="{StaticResource Pilula}" Content="Português"/>
              <Button x:Name="LingEN" Style="{StaticResource Pilula}" Content="English"/>
              <Button x:Name="LingES" Style="{StaticResource Pilula}" Content="Español"/>
              <Button x:Name="LingZH" Style="{StaticResource Pilula}" Content="中文"/>
            </WrapPanel>
            <Border Height="1" Background="#1F1F25" Margin="0,10,0,10"/>
            <TextBlock x:Name="Rodape" FontSize="11" Foreground="#6E685F" TextWrapping="Wrap"/>
          </StackPanel>
        </DockPanel>
      </Border>

      <!-- conteúdo -->
      <Grid Grid.Column="1">
        <Grid.RowDefinitions><RowDefinition Height="196"/><RowDefinition/><RowDefinition Height="92"/></Grid.RowDefinitions>
        <Border x:Name="Arte" Grid.Row="0" CornerRadius="0,11,0,0" Background="#1A0D10"/>
        <Border Grid.Row="0" CornerRadius="0,11,0,0">
          <Border.Background>
            <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
              <GradientStop Color="#220D0D10" Offset="0"/><GradientStop Color="#880D0D10" Offset="0.55"/><GradientStop Color="#FF0D0D10" Offset="1"/>
            </LinearGradientBrush>
          </Border.Background>
        </Border>
        <Border x:Name="Topo" Grid.Row="0" CornerRadius="0,11,0,0" Background="Transparent">
          <Grid>
            <Grid.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                <GradientStop Color="#CC0D0D10" Offset="0"/><GradientStop Color="#330D0D10" Offset="0.6"/><GradientStop Color="#000D0D10" Offset="1"/>
              </LinearGradientBrush>
            </Grid.Background>
            <StackPanel VerticalAlignment="Bottom" Margin="34,0,34,20">
              <TextBlock x:Name="TituloPagina" FontSize="32" FontWeight="Bold" Foreground="{StaticResource Texto}"/>
              <TextBlock x:Name="SubPagina" FontSize="13" Foreground="#C2BBAE" TextWrapping="Wrap" MaxWidth="650" HorizontalAlignment="Left" Margin="0,6,0,0" LineHeight="19"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,10,12,0">
              <Button x:Name="BtnMin" Style="{StaticResource Janela}" Content="&#xE921;"/>
              <Button x:Name="BtnFechar" Style="{StaticResource Janela}" Content="&#xE8BB;"/>
            </StackPanel>
          </Grid>
        </Border>
        <Border Grid.Row="0" Height="1" VerticalAlignment="Bottom" Margin="34,0,34,0">
          <Border.Background>
            <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
              <GradientStop Color="#00A3262C" Offset="0"/><GradientStop Color="#CCA3262C" Offset="0.25"/><GradientStop Color="#00A3262C" Offset="1"/>
            </LinearGradientBrush>
          </Border.Background>
        </Border>

        <ScrollViewer Grid.Row="1" x:Name="Rolagem" VerticalScrollBarVisibility="Auto" Margin="0,2,6,0">
          <StackPanel Margin="34,16,28,16">
            <StackPanel x:Name="PagMods">
              <Grid Margin="0,0,0,12">
                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <TextBlock x:Name="SecMods" FontSize="13" FontWeight="Bold" Foreground="{StaticResource Ouro}" VerticalAlignment="Center"/>
                <Button x:Name="BtnAtualizacoes" Grid.Column="1" Style="{StaticResource BotaoEscuro}"/>
              </Grid>
              <StackPanel x:Name="ListaMods"/>
              <Border x:Name="CaixaCompat" CornerRadius="8" Background="#121014" BorderBrush="#3A2A20" BorderThickness="1" Padding="14,10" Margin="0,4,0,0">
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE71B;" FontFamily="Segoe MDL2 Assets" FontSize="13" Foreground="{StaticResource Ouro}" Margin="0,2,10,0"/>
                  <TextBlock x:Name="TxtCompat" FontSize="12.5" Foreground="#CFC6B6" TextWrapping="Wrap"/>
                </StackPanel>
              </Border>
            </StackPanel>
            <StackPanel x:Name="PagFix" Visibility="Collapsed">
              <TextBlock x:Name="SecFix" FontSize="13" FontWeight="Bold" Foreground="{StaticResource Ouro}" Margin="0,0,0,12"/>
              <Border x:Name="CaixaResumo" CornerRadius="9" Background="#141417" BorderBrush="#2C2C33" BorderThickness="1" Padding="16,10" Margin="0,0,0,12">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock x:Name="IconeResumo" FontFamily="Segoe MDL2 Assets" FontSize="18" Margin="0,1,12,0" Foreground="#8F897E" Text="&#xE9F5;"/>
                    <TextBlock x:Name="ResumoFix" FontSize="14.5" Foreground="{StaticResource Texto}" TextWrapping="Wrap" VerticalAlignment="Center" MaxWidth="480"/>
                  </StackPanel>
                  <Button x:Name="BtnSecundario" Grid.Column="1" Style="{StaticResource BotaoEscuro}" Margin="12,0,0,0"/>
                </Grid>
              </Border>
              <StackPanel x:Name="ListaProblemas"/>
            </StackPanel>
            <StackPanel x:Name="PagAjuda" Visibility="Collapsed">
              <TextBlock x:Name="SecAjuda" FontSize="13" FontWeight="Bold" Foreground="{StaticResource Ouro}" Margin="0,0,0,12"/>
              <StackPanel x:Name="ListaPassos"/>
              <Border CornerRadius="8" Background="#121014" BorderBrush="#3A2A20" BorderThickness="1" Padding="14,10" Margin="0,4,0,0">
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE82F;" FontFamily="Segoe MDL2 Assets" FontSize="13" Foreground="{StaticResource Ouro}" Margin="0,2,10,0"/>
                  <TextBlock x:Name="TxtDica" FontSize="12.5" Foreground="#CFC6B6" TextWrapping="Wrap" MaxWidth="700"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </StackPanel>
        </ScrollViewer>

        <Border Grid.Row="2" CornerRadius="0,0,11,0" Background="#09090B" BorderBrush="#1D1D22" BorderThickness="0,1,0,0">
          <Grid Margin="34,0,24,0">
            <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <StackPanel VerticalAlignment="Center">
              <TextBlock x:Name="LblPasta" FontSize="10.5" FontWeight="Bold" Foreground="{StaticResource Ouro}"/>
              <StackPanel Orientation="Horizontal" Margin="0,5,0,0">
                <TextBox x:Name="CaixaPasta" Style="{StaticResource Caixa}" Width="270" FontSize="12"/>
                <Button x:Name="BtnProcurar" Style="{StaticResource BotaoEscuro}" Margin="8,0,0,0"/>
                <Button x:Name="BtnBuscarPC" Style="{StaticResource BotaoEscuro}" Margin="6,0,0,0"/>
              </StackPanel>
              <StackPanel Orientation="Horizontal" Margin="1,5,0,0">
                <TextBlock x:Name="IconePasta" FontFamily="Segoe MDL2 Assets" FontSize="11" Margin="0,1,6,0"/>
                <TextBlock x:Name="EstadoPasta" FontSize="11.5"/>
              </StackPanel>
            </StackPanel>
            <Button x:Name="BtnPrincipal" Grid.Column="1" Style="{StaticResource BotaoSangue}" VerticalAlignment="Center" Margin="16,0,0,0"/>
          </Grid>
        </Border>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

# ---------------------------------------------------------------- montagem
$script:Win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$XAML)))
$script:U = @{}
foreach ($nome in @('Emblema', 'TituloApp', 'SubApp', 'CaixaBusca', 'DicaBusca', 'NavMods', 'NavModsTxt', 'NavFix', 'NavFixTxt', 'NavAjuda', 'NavAjudaTxt',
                    'LblIdioma', 'LingPT', 'LingEN', 'LingES', 'LingZH', 'Rodape', 'Arte', 'Topo', 'TituloPagina', 'SubPagina', 'BtnMin', 'BtnFechar',
                    'PagMods', 'SecMods', 'ListaMods', 'CaixaCompat', 'TxtCompat', 'PagFix', 'SecFix', 'CaixaResumo', 'IconeResumo', 'ResumoFix',
                    'ListaProblemas', 'PagAjuda', 'SecAjuda', 'ListaPassos', 'TxtDica', 'LblPasta', 'CaixaPasta', 'BtnProcurar', 'BtnBuscarPC',
                    'IconePasta', 'EstadoPasta', 'BtnSecundario', 'BtnPrincipal', 'BtnAtualizacoes')) {
    $script:U[$nome] = $script:Win.FindName($nome)
}
$script:PaginaAtual = 'mods'; $script:Itens = @(); $script:Chaves = @{}; $script:Estados = @()
$script:FonteTitulo = New-Object Windows.Media.FontFamily('Palatino Linotype')
$script:FonteTexto = New-Object Windows.Media.FontFamily('Segoe UI')
function Cor([string]$hex) { return (New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($hex))) }
function Imagem([string]$caminho) {
    $bi = New-Object Windows.Media.Imaging.BitmapImage
    $bi.BeginInit(); $bi.UriSource = New-Object Uri($caminho); $bi.CacheOption = 'OnLoad'; $bi.EndInit(); $bi.Freeze()
    return $bi
}
function Atualizar-Tela { $script:Win.Dispatcher.Invoke([Action] {}, [Windows.Threading.DispatcherPriority]::Background) }
# progresso na linha de estado da pasta (o rodapé não tem espaço para mais nada); Mostrar-Estado-Pasta devolve o normal
$script:AoProgredir = { param($t)
    $script:U.IconePasta.Text = [string][char]0xE895; $script:U.IconePasta.Foreground = Cor '#E0AE4E'
    $script:U.EstadoPasta.Text = $t; $script:U.EstadoPasta.Foreground = Cor '#E6CB92'; Atualizar-Tela }

function Carregar-Arte {
    # arte e fontes do próprio BB Port; sem ele, fontes do Windows e fundo vermelho-escuro
    $assets = $null
    if ($script:Porto) { $a = Join-Path $script:Porto '_internal\assets'; if ([IO.Directory]::Exists($a)) { $assets = $a } }
    $script:Assets = $assets
    if ($assets -and [IO.File]::Exists((Join-Path $assets 'fonts\Cinzel-Bold.ttf'))) {
        $uri = New-Object Uri(((Join-Path $assets 'fonts').TrimEnd('\') + '\'))
        $script:FonteTitulo = New-Object Windows.Media.FontFamily($uri, './#Cinzel Bold')    # nome interno da fonte (medido)
        if ([IO.File]::Exists((Join-Path $assets 'fonts\Inter-Regular.ttf'))) { $script:FonteTexto = New-Object Windows.Media.FontFamily($uri, './#Inter') }
    }
    $script:Win.FontFamily = $script:FonteTexto
    foreach ($n in @('TituloApp', 'TituloPagina', 'SecMods', 'SecFix', 'SecAjuda', 'BtnPrincipal', 'LblPasta')) { $script:U[$n].FontFamily = $script:FonteTitulo }
    if ($assets -and [IO.File]::Exists((Join-Path $assets 'emblem.png'))) {
        $script:U.Emblema.Source = Imagem (Join-Path $assets 'emblem.png'); $script:Win.Icon = $script:U.Emblema.Source
    }
    Trocar-Arte
}
function Trocar-Arte {
    $nome = if ($script:PaginaAtual -eq 'mods') { 'header.jpg' } else { 'hero.jpg' }
    if ($script:Assets -and [IO.File]::Exists((Join-Path $script:Assets $nome))) {
        $ib = New-Object Windows.Media.ImageBrush (Imagem (Join-Path $script:Assets $nome))
        $ib.Stretch = 'UniformToFill'; $ib.AlignmentY = 'Center'; $ib.AlignmentX = 'Right'
        $script:U.Arte.Background = $ib
    } else {
        $g = New-Object Windows.Media.LinearGradientBrush
        $g.StartPoint = '0,0'; $g.EndPoint = '1,1'
        $g.GradientStops.Add((New-Object Windows.Media.GradientStop ([Windows.Media.ColorConverter]::ConvertFromString('#2A0E12')), 0))
        $g.GradientStops.Add((New-Object Windows.Media.GradientStop ([Windows.Media.ColorConverter]::ConvertFromString('#0D0D10')), 1))
        $script:U.Arte.Background = $g
    }
}

# ---------------------------------------------------------------- textos
function Atualizar-Textos {
    $U = $script:U
    $U.SubApp.Text = T 'app_sub'; $U.DicaBusca.Text = T 'busca'
    $U.NavModsTxt.Text = T 'nav_mods'; $U.NavFixTxt.Text = T 'nav_fix'; $U.NavAjudaTxt.Text = T 'nav_ajuda'
    $U.LblIdioma.Text = T 'idioma'; $U.Rodape.Text = 'Blood Reborn  ·  ' + (T 'rodape')
    $U.SecMods.Text = T 'sec_mods'; $U.SecFix.Text = T 'sec_fix'; $U.SecAjuda.Text = T 'sec_ajuda'; $U.TxtDica.Text = T 'dica'
    $U.LblPasta.Text = T 'pasta'; $U.BtnProcurar.Content = T 'procurar'; $U.BtnBuscarPC.Content = T 'buscar'
    foreach ($par in @(@('LingPT', 'pt'), @('LingEN', 'en'), @('LingES', 'es'), @('LingZH', 'zh'))) {
        if ($script:Ling -eq $par[1]) { $U[$par[0]].Tag = 'sel' } else { $U[$par[0]].Tag = $null }
    }
    Mostrar-Estado-Pasta; Montar-Passos; Montar-Cartoes; Mostrar-Pagina $script:PaginaAtual
}
function Mostrar-Estado-Pasta {
    $U = $script:U
    if ($script:Porto) {
        $U.CaixaPasta.Text = $script:Porto; $U.IconePasta.Text = [string][char]0xE73E; $U.IconePasta.Foreground = Cor '#6FBF73'
        $U.EstadoPasta.Text = T 'porto_ok'; $U.EstadoPasta.Foreground = Cor '#8FCB92'
    } elseif ($U.CaixaPasta.Text) {
        $U.IconePasta.Text = [string][char]0xE783; $U.IconePasta.Foreground = Cor '#D9534F'
        $U.EstadoPasta.Text = T 'porto_ruim'; $U.EstadoPasta.Foreground = Cor '#E07A76'
    } else {
        $U.IconePasta.Text = [string][char]0xE838; $U.IconePasta.Foreground = Cor '#8F897E'
        $U.EstadoPasta.Text = T 'porto_nada'; $U.EstadoPasta.Foreground = Cor '#8F897E'
    }
}

# ---------------------------------------------------------------- páginas
function Mostrar-Pagina([string]$qual) {
    $U = $script:U; $script:PaginaAtual = $qual
    $U.PagMods.Visibility = 'Collapsed'; $U.PagFix.Visibility = 'Collapsed'; $U.PagAjuda.Visibility = 'Collapsed'
    $U.NavMods.Tag = $null; $U.NavFix.Tag = $null; $U.NavAjuda.Tag = $null
    $U.BtnSecundario.Visibility = 'Collapsed'
    switch ($qual) {
        'mods' {
            $U.PagMods.Visibility = 'Visible'; $U.NavMods.Tag = 'sel'
            $U.TituloPagina.Text = T 't_mods'; $U.SubPagina.Text = T 's_mods'; $U.BtnPrincipal.Content = T 'aplicar'
            $U.BtnPrincipal.IsEnabled = [bool]($script:Porto -and @($script:Pacotes).Count)
            $U.BtnAtualizacoes.Content = T 'u_procurar'; $U.BtnAtualizacoes.IsEnabled = [bool]$script:Porto
        }
        'correcao' {
            $U.PagFix.Visibility = 'Visible'; $U.NavFix.Tag = 'sel'
            $U.TituloPagina.Text = T 't_fix'; $U.SubPagina.Text = T 's_fix'; $U.BtnPrincipal.Content = T 'corrigir'
            $U.BtnSecundario.Visibility = 'Visible'; $U.BtnSecundario.Content = T 'verificar'
            $U.BtnSecundario.IsEnabled = [bool]$script:Porto
            $U.BtnPrincipal.IsEnabled = [bool](@($script:Itens | Where-Object { $_.Corrige }).Count)
        }
        'ajuda' {
            $U.PagAjuda.Visibility = 'Visible'; $U.NavAjuda.Tag = 'sel'
            $U.TituloPagina.Text = T 't_ajuda'; $U.SubPagina.Text = T 's_ajuda'; $U.BtnPrincipal.Content = T 'comecar'
            $U.BtnPrincipal.IsEnabled = $true
        }
    }
    Trocar-Arte; Filtrar
}
function Novo-Texto([string]$texto, [double]$tam, [string]$cor, [string]$peso = 'Normal') {
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = $texto; $t.FontSize = $tam; $t.Foreground = Cor $cor; $t.FontWeight = $peso; $t.TextWrapping = 'Wrap'
    return $t
}
function Novo-Chip([string]$texto, [string]$cor, [string]$fundo) {
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = 10; $b.Padding = '10,3'; $b.Background = Cor $fundo; $b.BorderBrush = Cor $cor; $b.BorderThickness = 1
    $b.VerticalAlignment = 'Top'; $b.Child = Novo-Texto $texto 11 $cor 'SemiBold'
    return $b
}
function Novo-Cartao {
    $c = New-Object Windows.Controls.Border
    $c.CornerRadius = 10; $c.Background = Cor '#141417'; $c.BorderBrush = Cor '#24242A'; $c.BorderThickness = 1
    $c.Padding = '18,14'; $c.Margin = '0,0,0,10'
    $c.Add_MouseEnter({ param($s) $s.BorderBrush = Cor '#4A2629' }); $c.Add_MouseLeave({ param($s) $s.BorderBrush = Cor '#24242A' })
    return $c
}
function Montar-Cartoes {
    $L = $script:U.ListaMods; $antes = @{}
    foreach ($k in $script:Chaves.Keys) { $antes[$k] = $script:Chaves[$k].IsChecked }
    $L.Children.Clear(); $script:Chaves = @{}
    if (@($script:Pacotes).Count -eq 0) { [void]$L.Children.Add((Novo-Texto (T 'sem_pac') 13 '#E07A76')); Atualizar-Compat; return }
    $dm = $null; if ($script:Porto) { $dm = Join-Path $script:Porto 'mods' }
    # fase 2 (04/11): o estado de atualização da última busca (Procurar-UI), por pasta
    $est = @{}; foreach ($x in @($script:Estados)) { if ($x -and $x.Pasta) { $est[$x.Pasta] = $x } }
    foreach ($p in $script:Pacotes) {
        $e = $est[$p.Pasta]; $vi = if ($dm) { Versao-Instalada $script:Porto $p.Pasta } else { $null }
        $estado = 'st_nao'; $inst = [bool]$vi
        if ($inst) {
            $alvo = Join-Path $dm $p.Pasta; $ruins = Conferir-Registro $alvo -Rapido
            if ($ruins -lt 0) { $ruins = Conferir-Pasta $p.Zip $p.Prefixo $alvo -Rapido }
            if ($ruins -gt 0) { $estado = 'st_rep' } elseif ($vi -eq 'unknown') { $estado = 'st_desc' } elseif ($e -and $e.Atualizar) { $estado = 'st_nova' } else { $estado = 'st_inst' }
        }
        $card = Novo-Cartao
        $g = New-Object Windows.Controls.Grid
        foreach ($w in @('Auto', '*', 'Auto')) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = $w; [void]$g.ColumnDefinitions.Add($cd) }
        $chk = New-Object Windows.Controls.CheckBox
        $chk.Style = $script:Win.FindResource('Chave'); $chk.VerticalAlignment = 'Top'; $chk.Margin = '0,2,18,0'
        if ($antes.ContainsKey($p.Pasta)) { $chk.IsChecked = $antes[$p.Pasta] } else { $chk.IsChecked = $inst }
        $chk.Add_Click({ Atualizar-Compat })
        [Windows.Controls.Grid]::SetColumn($chk, 0); [void]$g.Children.Add($chk)
        $pilha = New-Object Windows.Controls.StackPanel
        $linha = New-Object Windows.Controls.StackPanel; $linha.Orientation = 'Horizontal'
        $nome = Novo-Texto $p.Nome 16.5 '#F1EADD' 'SemiBold'; $nome.TextWrapping = 'NoWrap'; [void]$linha.Children.Add($nome)
        $txtVer = if ($inst -and $e -and $e.Disponivel -and $vi -ne $e.Disponivel) { (T 'u_linha') -f $vi, $e.Disponivel } elseif ($inst) { 'v' + $vi } else { 'v' + $p.Versao }
        $ver = Novo-Texto $txtVer 11.5 '#8F897E'; $ver.Margin = '9,5,0,0'; [void]$linha.Children.Add($ver)
        [void]$pilha.Children.Add($linha)
        $desc = Novo-Texto ([string]$p.Desc[$script:Ling]) 12.5 '#A7A094'; $desc.Margin = '0,7,0,0'; $desc.LineHeight = 19
        if (-not $desc.Text) { $desc.Text = [string]$p.Desc['en'] }
        [void]$pilha.Children.Add($desc)
        [Windows.Controls.Grid]::SetColumn($pilha, 1); [void]$g.Children.Add($pilha)
        $cores = @{ st_inst = @('#7CC482', '#16241A'); st_nao = @('#8F897E', '#18181C'); st_rep = @('#E0AE4E', '#2A2214')
                    st_nova = @('#7FB2E5', '#14202B'); st_desc = @('#E0AE4E', '#2A2214') }
        $dir = New-Object Windows.Controls.StackPanel; $dir.Margin = '14,1,0,0'
        $chip = Novo-Chip (T $estado) $cores[$estado][0] $cores[$estado][1]; $chip.HorizontalAlignment = 'Right'; [void]$dir.Children.Add($chip)
        if ($e -and $e.Atualizar) {
            $b = New-Object Windows.Controls.Button; $b.Style = $script:Win.FindResource('BotaoEscuro'); $b.Margin = '0,8,0,0'
            $b.Content = (T 'u_btn') -f $e.Disponivel; $b.Tag = $p.Pasta; $b.Add_Click({ param($s) Atualizar-UI ([string]$s.Tag) }); [void]$dir.Children.Add($b)
        }
        if ($e -and @($e.Notas).Count) {
            $b = New-Object Windows.Controls.Button; $b.Style = $script:Win.FindResource('BotaoEscuro'); $b.Margin = '0,6,0,0'
            $b.Content = T 'u_notas'; $b.Tag = $p.Pasta; $b.Add_Click({ param($s) Notas-UI ([string]$s.Tag) }); [void]$dir.Children.Add($b)
        }
        $va = Versao-Anterior $p.Pasta
        if ($inst -and $va) {
            $b = New-Object Windows.Controls.Button; $b.Style = $script:Win.FindResource('BotaoEscuro'); $b.Margin = '0,6,0,0'
            $b.Content = (T 'u_voltar') -f $va; $b.Tag = $p.Pasta; $b.Add_Click({ param($s) Voltar-UI ([string]$s.Tag) }); [void]$dir.Children.Add($b)
        }
        [Windows.Controls.Grid]::SetColumn($dir, 2); [void]$g.Children.Add($dir)
        $card.Child = $g; $card.Tag = ($p.Nome + ' ' + $p.Pasta + ' ' + $desc.Text).ToLowerInvariant()
        [void]$L.Children.Add($card); $script:Chaves[$p.Pasta] = $chk
    }
    Atualizar-Compat; Filtrar
}
function Escolhidos { return @($script:Pacotes | Where-Object { $script:Chaves[$_.Pasta] -and $script:Chaves[$_.Pasta].IsChecked } | ForEach-Object { $_.Pasta }) }
function Atualizar-Compat {
    $quero = @(Escolhidos)
    $cs = @($script:Compat | Where-Object { $c = $_; @($c.Mods | Where-Object { $quero -notcontains $_ }).Count -eq 0 } | ForEach-Object { $_.Pasta -replace '^Blood Reborn - zCompat ', '' })
    if ($cs.Count) { $script:U.TxtCompat.Text = (T 'compat') -f ($cs -join '  ·  ') } else { $script:U.TxtCompat.Text = T 'compat0' }
}
function Montar-Passos {
    $L = $script:U.ListaPassos; $L.Children.Clear(); $n = 0
    foreach ($k in @('h1', 'h2', 'h3', 'h4')) {
        $n++; $card = Novo-Cartao
        $g = New-Object Windows.Controls.Grid
        foreach ($w in @('Auto', '*')) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = $w; [void]$g.ColumnDefinitions.Add($cd) }
        $num = Novo-Texto ([string]$n) 30 '#B8323A' 'Bold'; $num.FontFamily = $script:FonteTitulo; $num.Width = 46; $num.Margin = '0,-4,8,0'
        [Windows.Controls.Grid]::SetColumn($num, 0); [void]$g.Children.Add($num)
        $rotulo = Novo-Texto (T $k) 14 '#E3DCCF'; $rotulo.VerticalAlignment = 'Center'; $rotulo.LineHeight = 21
        [Windows.Controls.Grid]::SetColumn($rotulo, 1); [void]$g.Children.Add($rotulo)
        $card.Child = $g; $card.Tag = $rotulo.Text.ToLowerInvariant(); [void]$L.Children.Add($card)
    }
}
function Montar-Problemas {
    $L = $script:U.ListaProblemas; $L.Children.Clear()
    $icones = @{ erro = @([string][char]0xE783, '#E0625D'); aviso = @([string][char]0xE7BA, '#E0AE4E'); ok = @([string][char]0xE73E, '#7CC482') }
    foreach ($it in $script:Itens) {
        $card = Novo-Cartao; $card.Padding = '16,11'; $card.Margin = '0,0,0,7'
        $g = New-Object Windows.Controls.Grid
        foreach ($w in @('Auto', '*', 'Auto')) { $cd = New-Object Windows.Controls.ColumnDefinition; $cd.Width = $w; [void]$g.ColumnDefinitions.Add($cd) }
        $ic = Novo-Texto $icones[$it.Nivel][0] 14 $icones[$it.Nivel][1]; $ic.FontFamily = New-Object Windows.Media.FontFamily('Segoe MDL2 Assets'); $ic.Margin = '0,2,12,0'
        [Windows.Controls.Grid]::SetColumn($ic, 0); [void]$g.Children.Add($ic)
        $tx = Novo-Texto $it.Texto 13 '#DDD5C7'; $tx.LineHeight = 19
        [Windows.Controls.Grid]::SetColumn($tx, 1); [void]$g.Children.Add($tx)
        if ($it.Corrige) { $chip = Novo-Chip (T 'chip_fix') '#C4535A' '#26131A'; $chip.Margin = '12,0,0,0'; [Windows.Controls.Grid]::SetColumn($chip, 2); [void]$g.Children.Add($chip) }
        $card.Child = $g; $card.Tag = $it.Texto.ToLowerInvariant(); [void]$L.Children.Add($card)
    }
    $erros = @($script:Itens | Where-Object { $_.Nivel -ne 'ok' }); $corr = @($script:Itens | Where-Object { $_.Corrige })
    if (-not $script:Porto) { $script:U.ResumoFix.Text = T 'v_porto'; $script:U.IconeResumo.Text = [string][char]0xE838; $script:U.IconeResumo.Foreground = Cor '#8F897E' }
    elseif ($erros.Count -eq 0) { $script:U.ResumoFix.Text = T 'v_ok'; $script:U.IconeResumo.Text = [string][char]0xE73E; $script:U.IconeResumo.Foreground = Cor '#7CC482' }
    else { $script:U.ResumoFix.Text = (T 'v_n') -f $erros.Count, $corr.Count; $script:U.IconeResumo.Text = [string][char]0xE7BA; $script:U.IconeResumo.Foreground = Cor '#E0AE4E' }
    $script:U.BtnPrincipal.IsEnabled = ($script:PaginaAtual -ne 'correcao') -or $corr.Count -gt 0
    Filtrar
}
function Filtrar {
    $q = ([string]$script:U.CaixaBusca.Text).Trim().ToLowerInvariant()
    if ($q) { $script:U.DicaBusca.Visibility = 'Collapsed' } else { $script:U.DicaBusca.Visibility = 'Visible' }
    foreach ($lista in @($script:U.ListaMods, $script:U.ListaProblemas, $script:U.ListaPassos)) {
        foreach ($c in $lista.Children) {
            if (-not $q -or -not ($c.Tag -is [string]) -or $c.Tag.Contains($q)) { $c.Visibility = 'Visible' } else { $c.Visibility = 'Collapsed' }
        }
    }
}

# ---------------------------------------------------------------- ações
function Ocupado([bool]$sim) {
    foreach ($n in @('BtnPrincipal', 'BtnSecundario', 'BtnAtualizacoes', 'BtnProcurar', 'BtnBuscarPC', 'NavMods', 'NavFix', 'NavAjuda')) { $script:U[$n].IsEnabled = -not $sim }
    if ($sim) { $script:Win.Cursor = [Windows.Input.Cursors]::Wait } else { $script:Win.Cursor = $null; Mostrar-Estado-Pasta; Mostrar-Pagina $script:PaginaAtual }
    Atualizar-Tela
}
function Aviso([string]$texto, [string]$icone = 'Information') { [void][Windows.MessageBox]::Show($script:Win, $texto, 'Blood Reborn', 'OK', $icone) }
function Definir-Porto([string]$p) {
    $p = ([string]$p).Trim().Trim('"')
    if (E-Port $p) { $script:Porto = $p; Gravar-Config } else { $script:Porto = $null; $script:U.CaixaPasta.Text = $p }
    Carregar-Arte; Mostrar-Estado-Pasta; Montar-Cartoes; $script:Itens = @()
    if ($script:PaginaAtual -eq 'correcao') { Verificar-UI } else { Montar-Problemas; Mostrar-Pagina $script:PaginaAtual }
}
function Verificar-UI {
    if (-not $script:Porto) { $script:Itens = @(); Montar-Problemas; return }
    Ocupado $true; & $script:AoProgredir (T 'conferindo')
    try { $script:Itens = @(Diagnosticar $script:Porto) } catch { Aviso ((T 'erro') -f $_.Exception.Message) 'Error' }
    Ocupado $false; Montar-Problemas
}
function Aplicar-UI {
    if (-not $script:Porto) { return }
    if (-not $SemTrava -and (Jogo-Aberto)) { Aviso (T 'aberto') 'Warning'; return }
    $quero = @(Escolhidos); $dm = Join-Path $script:Porto 'mods'
    $tirar = @($script:Pacotes | Where-Object { $quero -notcontains $_.Pasta -and [IO.Directory]::Exists((Join-Path $dm $_.Pasta)) } | ForEach-Object { '  - ' + $_.Nome })
    $por = @($script:Pacotes | Where-Object { $quero -contains $_.Pasta } | ForEach-Object { '  - ' + $_.Nome })
    $a = if ($por.Count) { $por -join "`n" } else { '  ' + (T 'nada') }
    $b = if ($tirar.Count) { $tirar -join "`n" } else { '  ' + (T 'nada') }
    if ([Windows.MessageBox]::Show($script:Win, ((T 'confirma') -f $a, $b), 'Blood Reborn', 'YesNo', 'Question') -ne 'Yes') { return }
    Ocupado $true
    try { [void](Aplicar-Escolha $script:Porto $quero); Ocupado $false; Montar-Cartoes; Aviso (T 'pronto') }
    catch { Ocupado $false; Aviso ((T 'erro') -f $_.Exception.Message) 'Error' }
}
function Corrigir-UI {
    $n = @($script:Itens | Where-Object { $_.Corrige }).Count
    if (-not $n) { return }
    if (-not $SemTrava -and (Jogo-Aberto)) { Aviso (T 'aberto') 'Warning'; return }
    if ([Windows.MessageBox]::Show($script:Win, ((T 'confirma_fix') -f $n), 'Blood Reborn', 'YesNo', 'Question') -ne 'Yes') { return }
    Ocupado $true
    try { [void](Corrigir-Tudo $script:Porto); Ocupado $false; Montar-Cartoes; Verificar-UI; Aviso (T 'corrigido') }
    catch { Ocupado $false; Aviso ((T 'erro') -f $_.Exception.Message) 'Error' }
}
# ---- fase 2 (04/11): atualizações. $script:Estados = último Estado-Atualizacoes, por pasta.
function Procurar-UI([switch]$Forcar) {
    if (-not $script:Porto) { return }
    Ocupado $true; & $script:AoProgredir (T 'conferindo')
    try { $script:Estados = @(Estado-Atualizacoes $script:Porto -Forcar:$Forcar) } catch { $script:Estados = @() }
    Ocupado $false; Montar-Cartoes
    if ($Forcar -and $script:AvisoRede) { Aviso $script:AvisoRede 'Warning' }   # ao abrir a janela, sem rede fica calado
    elseif ($Forcar -and -not @($script:Estados | Where-Object { $_.Atualizar }).Count) { Aviso (T 'u_nada_novo') }
}
function Atualizar-UI([string]$pasta) {
    if (-not $SemTrava -and (Jogo-Aberto)) { Aviso (T 'aberto') 'Warning'; return }
    $e = @($script:Estados | Where-Object { $_.Pasta -eq $pasta })[0]
    # Ocupado desliga tudo; o botão de atualizações volta ligado como Cancelar (a espera do Nexus grátis bombeia a tela
    # pelo AoProgredir, então o clique chega). Ocupado $false -> Mostrar-Pagina devolve o texto normal.
    $script:Cancelar = $false; Ocupado $true
    $script:U.BtnAtualizacoes.IsEnabled = $true; $script:U.BtnAtualizacoes.Content = T 'u_cancelar'
    try { [void](Atualizar-Mod $script:Porto $pasta); Ocupado $false; Procurar-UI; Aviso ((T 'u_ok') -f $e.Nome, $e.Disponivel) }
    catch { Ocupado $false; Montar-Cartoes; Aviso ((T 'erro') -f $_.Exception.Message) 'Error' }
}
function Voltar-UI([string]$pasta) {
    if (-not $SemTrava -and (Jogo-Aberto)) { Aviso (T 'aberto') 'Warning'; return }
    $nome = @($script:Pacotes | Where-Object { $_.Pasta -eq $pasta } | ForEach-Object { $_.Nome })[0]; if (-not $nome) { $nome = $pasta }
    Ocupado $true
    try { Voltar-Mod $script:Porto $pasta; Ocupado $false; Procurar-UI; Aviso ((T 'u_voltou') -f $nome) }
    catch { Ocupado $false; Montar-Cartoes; Aviso ((T 'erro') -f $_.Exception.Message) 'Error' }
}
function Notas-UI([string]$pasta) {
    $e = @($script:Estados | Where-Object { $_.Pasta -eq $pasta })[0]
    $t = (@($e.Notas) | ForEach-Object { 'v' + $_.Versao + "`n" + $_.Texto }) -join "`n`n"
    [void][Windows.MessageBox]::Show($script:Win, $t, ((T 'u_titulo_notas') -f $e.Nome), 'OK', 'Information')
}
function Chave-UI {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $v = [Microsoft.VisualBasic.Interaction]::InputBox((T 'u_chave'), 'Blood Reborn', '')
    Gravar-Chave-Nexus ([string]$v).Trim()
}
function Buscar-UI {
    Ocupado $true
    $achados = @(Buscar-Ports)
    Ocupado $false
    if ($achados.Count -eq 0) { Aviso (T 'achou0') 'Warning'; return }
    if ($achados.Count -eq 1) { Definir-Porto $achados[0]; return }
    $menu = New-Object Windows.Controls.ContextMenu
    foreach ($a in $achados) {
        $mi = New-Object Windows.Controls.MenuItem; $mi.Header = $a; $mi.Tag = $a
        $mi.Add_Click({ param($s) Definir-Porto ([string]$s.Tag) }); [void]$menu.Items.Add($mi)
    }
    $menu.PlacementTarget = $script:U.BtnBuscarPC; $menu.IsOpen = $true
}

# ---------------------------------------------------------------- eventos
$U = $script:U
$U.Topo.Add_MouseLeftButtonDown({ $script:Win.DragMove() })
$U.BtnFechar.Add_Click({ $script:Win.Close() })
$U.BtnMin.Add_Click({ $script:Win.WindowState = 'Minimized' })
$U.NavMods.Add_Click({ Mostrar-Pagina 'mods' })
$U.NavFix.Add_Click({ Mostrar-Pagina 'correcao'; Verificar-UI })
$U.NavAjuda.Add_Click({ Mostrar-Pagina 'ajuda' })
$U.LingPT.Add_Click({ $script:Ling = 'pt'; Gravar-Config; Atualizar-Textos; if ($script:PaginaAtual -eq 'correcao') { Verificar-UI } })
$U.LingEN.Add_Click({ $script:Ling = 'en'; Gravar-Config; Atualizar-Textos; if ($script:PaginaAtual -eq 'correcao') { Verificar-UI } })
$U.LingES.Add_Click({ $script:Ling = 'es'; Gravar-Config; Atualizar-Textos; if ($script:PaginaAtual -eq 'correcao') { Verificar-UI } })
$U.LingZH.Add_Click({ $script:Ling = 'zh'; Gravar-Config; Atualizar-Textos; if ($script:PaginaAtual -eq 'correcao') { Verificar-UI } })
$U.CaixaBusca.Add_TextChanged({ Filtrar })
$U.CaixaPasta.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Return') { Definir-Porto $script:U.CaixaPasta.Text } })
$U.CaixaPasta.Add_LostFocus({ if ($script:U.CaixaPasta.Text -ne [string]$script:Porto) { Definir-Porto $script:U.CaixaPasta.Text } })
$U.BtnProcurar.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description = T 'escolha'
    if ($script:Porto) { $d.SelectedPath = $script:Porto }
    if ($d.ShowDialog() -eq 'OK') { Definir-Porto $d.SelectedPath }
})
$U.BtnBuscarPC.Add_Click({ Buscar-UI })
$U.BtnSecundario.Add_Click({ Verificar-UI })
$U.BtnAtualizacoes.Add_Click({
    if ($script:U.BtnAtualizacoes.Content -eq (T 'u_cancelar')) { $script:Cancelar = $true; return }
    Procurar-UI -Forcar
})
# botão direito no de atualizações: a chave da API do Nexus (conta Premium). O texto acompanha o idioma (Opened).
$mk = New-Object Windows.Controls.ContextMenu; $mi = New-Object Windows.Controls.MenuItem
$mk.Add_Opened({ $script:ItemChave.Header = T 'u_btn_chave' }); $script:ItemChave = $mi
$mi.Add_Click({ Chave-UI }); [void]$mk.Items.Add($mi); $U.BtnAtualizacoes.ContextMenu = $mk
$U.BtnPrincipal.Add_Click({
    switch ($script:PaginaAtual) { 'mods' { Aplicar-UI } 'correcao' { Corrigir-UI } 'ajuda' { Mostrar-Pagina 'mods' } }
})
$script:Win.Add_KeyDown({ param($s, $e)
    if ($e.Key -eq 'F' -and ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control)) { $script:U.CaixaBusca.Focus(); $script:U.CaixaBusca.SelectAll() }
    if ($e.Key -eq 'Escape' -and $script:U.CaixaBusca.Text) { $script:U.CaixaBusca.Text = '' }
})

# ---------------------------------------------------------------- início
Ler-Pacotes
$script:Porto = Achar-Port-Rapido
Carregar-Arte
$script:PaginaAtual = $Pagina
Atualizar-Textos
if ($Captura) {
    # imagem da janela para conferência, sem mostrar nada na tela
    if ($script:Porto) { $script:Estados = @(Estado-Atualizacoes $script:Porto -Forcar) }; Montar-Cartoes
    if ($Pagina -eq 'correcao') { if ($script:Porto) { $script:Itens = @(Diagnosticar $script:Porto) }; Mostrar-Estado-Pasta; Montar-Problemas }
    $raiz = $script:Win.Content
    $raiz.Measure((New-Object Windows.Size($script:Win.Width, $script:Win.Height)))
    $raiz.Arrange((New-Object Windows.Rect(0, 0, $script:Win.Width, $script:Win.Height))); $raiz.UpdateLayout()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$script:Win.Width, [int]$script:Win.Height, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($raiz)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [IO.File]::Create($Captura); try { $enc.Save($fs) } finally { $fs.Close() }
    exit 0
}
$script:Win.Add_ContentRendered({
    if (-not $script:Porto) {
        Ocupado $true; $achados = @(Buscar-Ports 4 25000); Ocupado $false
        if ($achados.Count -ge 1) { Definir-Porto $achados[0] } else { Mostrar-Estado-Pasta }
    }
    if ($script:Porto) { Procurar-UI }   # usa o cache de 24 h: rápido e calado
    if ($script:PaginaAtual -eq 'correcao') { Verificar-UI }
})
[void]$script:Win.ShowDialog()
