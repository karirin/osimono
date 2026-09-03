@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.osimono.android.ui

import android.annotation.SuppressLint
import android.app.DatePickerDialog
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.DrawableRes
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.content.res.AppCompatResources
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CardGiftcard
import androidx.compose.material.icons.rounded.ChatBubbleOutline
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Face
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.Place
import androidx.compose.material.icons.rounded.PhotoCamera
import androidx.compose.material.icons.rounded.PostAdd
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.net.toUri
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import coil.compose.AsyncImage
import com.osimono.android.data.AppContainer
import com.osimono.android.model.EventLocation
import com.osimono.android.model.Oshi
import com.osimono.android.model.OshiItem
import com.osimono.android.R
import com.osimono.android.ui.components.ChoiceChipRow
import com.osimono.android.ui.components.DetailRow
import com.osimono.android.ui.components.EmptyStateCard
import com.osimono.android.ui.components.ImagePreviewCard
import com.osimono.android.ui.components.SectionCard
import com.osimono.android.ui.components.StatusChip
import com.osimono.android.ui.theme.OshiBlue
import com.osimono.android.ui.theme.OshiIndigo
import com.osimono.android.ui.theme.OshiPink
import com.osimono.android.ui.theme.OshiPurple
import com.osimono.android.ui.theme.OshiSurfaceAlt
import com.osimono.android.ui.theme.OshiTextMuted
import com.osimono.android.util.currentTimestampSeconds
import java.io.File
import java.io.FileOutputStream
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

private sealed class Destination(
    val route: String,
    val label: String = "",
    val icon: ImageVector = Icons.Rounded.Face,
) {
    data object Oshis : Destination("oshis", "推しログ", Icons.Rounded.Dashboard)
    data object Items : Destination("items", "投稿", Icons.Rounded.PostAdd)
    data object Places : Destination("places", "聖地巡礼", Icons.Rounded.Place)
    data object Chat : Destination("chat", "チャット", Icons.Rounded.ChatBubbleOutline)
    data object Groups : Destination("groups", "グループチャット", Icons.Rounded.Groups)
    data object Settings : Destination("settings", "設定", Icons.Rounded.Settings)
    data object OshiForm : Destination("oshi_form/{oshiId}") {
        fun createRoute(oshiId: String) = "oshi_form/$oshiId"
    }

    data object ItemForm : Destination("item_form/{itemId}") {
        fun createRoute(itemId: String) = "item_form/$itemId"
    }

    data object ItemDetail : Destination("item_detail/{itemId}") {
        fun createRoute(itemId: String) = "item_detail/$itemId"
    }

    data object LocationForm : Destination("location_form/{locationId}") {
        fun createRoute(locationId: String) = "location_form/$locationId"
    }
}

private val GoodsCategoryOptions = listOf(
    "グッズ",
    "CD・DVD",
    "雑誌",
    "写真集",
    "アクリルスタンド",
    "ぬいぐるみ",
    "Tシャツ",
    "タオル",
    "その他",
)

private val OshiGenderOptions = listOf("男性", "女性", "その他")
private val ItemTypeFilterOptions = listOf("すべて") + OshiItemTypeOptions
private val SortOptionLabels = listOf("新しい順", "古い順", "価格高い順", "価格安い順", "お気に入り順")
private val CategoryFilterOptions = listOf("すべて") + GoodsCategoryOptions

private data class TestImagePreset(
    val label: String,
    @DrawableRes val drawableRes: Int,
    val cacheFileName: String,
)

private val OshiProfileTestPresets = listOf(
    TestImagePreset("ローズ", R.drawable.test_profile_rose, "oshi_profile_rose.png"),
    TestImagePreset("ミント", R.drawable.test_profile_mint, "oshi_profile_mint.png"),
)

private val OshiBackgroundTestPresets = listOf(
    TestImagePreset("サンセット", R.drawable.test_banner_sunset, "oshi_background_sunset.png"),
    TestImagePreset("ネオン", R.drawable.test_banner_neon, "oshi_background_neon.png"),
)

private val LocationImageTestPresets = listOf(
    TestImagePreset("カフェ", R.drawable.test_spot_cafe, "location_cafe.png"),
    TestImagePreset("ライブ会場", R.drawable.test_post_live, "location_live.png"),
    TestImagePreset("夕焼け", R.drawable.test_banner_sunset, "location_sunset.png"),
)

private fun itemImageTestPresets(itemType: String): List<TestImagePreset> = when (itemType) {
    "グッズ" -> listOf(
        TestImagePreset("グッズ", R.drawable.test_post_goods, "item_goods.png"),
        TestImagePreset("SNS風", R.drawable.test_post_sns, "item_goods_sns.png"),
    )

    "ライブ記録" -> listOf(
        TestImagePreset("ライブ", R.drawable.test_post_live, "item_live.png"),
        TestImagePreset("ネオン", R.drawable.test_banner_neon, "item_live_neon.png"),
    )

    "聖地巡礼" -> listOf(
        TestImagePreset("カフェ", R.drawable.test_spot_cafe, "item_spot_cafe.png"),
        TestImagePreset("夕焼け", R.drawable.test_banner_sunset, "item_spot_sunset.png"),
    )

    "SNS投稿" -> listOf(
        TestImagePreset("SNS風", R.drawable.test_post_sns, "item_sns.png"),
        TestImagePreset("ネオン", R.drawable.test_banner_neon, "item_sns_neon.png"),
    )

    else -> listOf(
        TestImagePreset("グッズ", R.drawable.test_post_goods, "item_other_goods.png"),
        TestImagePreset("ライブ", R.drawable.test_post_live, "item_other_live.png"),
    )
}

@Composable
fun OsimonoApp(container: AppContainer) {
    val viewModel: MainViewModel = viewModel(factory = MainViewModel.Factory(container))
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    val snackbarHostState = remember { SnackbarHostState() }
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val tabDestinations = listOf(
        Destination.Oshis,
        Destination.Places,
        Destination.Chat,
        Destination.Groups,
        Destination.Settings,
    )
    val selectedTabRoute = when {
        currentRoute?.startsWith("item_form") == true -> Destination.Oshis.route
        currentRoute?.startsWith("item_detail") == true -> Destination.Oshis.route
        currentRoute?.startsWith("oshi_form") == true -> Destination.Oshis.route
        currentRoute?.startsWith("location_form") == true -> Destination.Places.route
        else -> currentRoute
    }

    LaunchedEffect(uiState.transientMessage) {
        uiState.transientMessage?.let { message ->
            snackbarHostState.showSnackbar(message)
            viewModel.consumeTransientMessage()
        }
    }

    if (uiState.isInitializing && uiState.userId == null) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator()
        }
        return
    }

    if (uiState.userId == null) {
        InitializationErrorScreen(
            message = uiState.initializationError ?: "初期化に失敗しました",
            onRetry = viewModel::retryInitialization,
        )
        return
    }

    Scaffold(
        modifier = Modifier.windowInsetsPadding(WindowInsets.safeDrawing),
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            if (currentRoute in tabDestinations.map { it.route } &&
                currentRoute != Destination.Oshis.route &&
                currentRoute != Destination.Places.route
            ) {
                Column {
                    TopAppBar(
                        title = {
                            Column {
                                Text(text = "osimono Android", fontWeight = FontWeight.Bold)
                                Text(
                                    text = uiState.selectedOshi?.name ?: "推しを追加してください",
                                    style = MaterialTheme.typography.labelMedium,
                                )
                            }
                        },
                    )
                    if (uiState.isWorking) {
                        LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                    }
                }
            }
        },
        bottomBar = {
            Column {
                HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.55f))
                NavigationBar(
                    modifier = Modifier.height(84.dp),
                    containerColor = MaterialTheme.colorScheme.surface,
                    tonalElevation = 0.dp,
                ) {
                    tabDestinations.forEach { destination ->
                        NavigationBarItem(
                            selected = selectedTabRoute == destination.route,
                            onClick = {
                                navController.navigate(destination.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    destination.icon,
                                    contentDescription = destination.label,
                                    modifier = Modifier.size(26.dp),
                                )
                            },
                            label = {
                                Text(
                                    destination.label,
                                    style = MaterialTheme.typography.labelSmall,
                                    maxLines = 1,
                                )
                            },
                            alwaysShowLabel = true,
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = OshiBlue,
                                selectedTextColor = OshiBlue,
                                unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                indicatorColor = Color.Transparent,
                            ),
                        )
                    }
                }
            }
        },
        floatingActionButton = {
            when (currentRoute) {
                Destination.Oshis.route -> {
                    GradientFab(
                        onClick = {
                            if (uiState.selectedOshi != null) {
                                navController.navigate(Destination.ItemForm.createRoute(NEW_ENTRY_ID))
                            } else {
                                navController.navigate(Destination.OshiForm.createRoute(NEW_ENTRY_ID))
                            }
                        },
                        contentDescription = if (uiState.selectedOshi != null) "推しアイテムを追加" else "推しを追加",
                    )
                }

                Destination.Places.route -> {
                    if (uiState.selectedOshi != null) {
                        GradientFab(
                            onClick = { navController.navigate(Destination.LocationForm.createRoute(NEW_ENTRY_ID)) },
                            contentDescription = "場所を追加",
                        )
                    }
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Destination.Oshis.route,
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            composable(Destination.Oshis.route) {
                OshiLogScreen(
                    uiState = uiState,
                    onSelect = viewModel::selectOshi,
                    onAddOshi = { navController.navigate(Destination.OshiForm.createRoute(NEW_ENTRY_ID)) },
                    onEditOshi = { navController.navigate(Destination.OshiForm.createRoute(it)) },
                    onAddItem = { navController.navigate(Destination.ItemForm.createRoute(NEW_ENTRY_ID)) },
                    onOpenItem = { navController.navigate(Destination.ItemDetail.createRoute(it)) },
                )
            }
            composable(Destination.Places.route) {
                PlacesScreen(
                    uiState = uiState,
                    onEdit = { navController.navigate(Destination.LocationForm.createRoute(it)) },
                )
            }
            composable(Destination.Chat.route) {
                ChatPlaceholderScreen(uiState = uiState)
            }
            composable(Destination.Groups.route) {
                GroupPlaceholderScreen(uiState = uiState)
            }
            composable(Destination.Settings.route) {
                SettingsScreen(uiState = uiState, onSave = viewModel::saveProfile)
            }
            composable(
                route = Destination.OshiForm.route,
                arguments = listOf(navArgument("oshiId") { type = NavType.StringType }),
            ) { entry ->
                val oshiId = entry.arguments?.getString("oshiId").orEmpty()
                OshiFormScreen(
                    existing = uiState.oshis.firstOrNull { it.id == oshiId },
                    isSaving = uiState.isWorking,
                    onBack = { navController.popBackStack() },
                    onSave = { draft, profileUri, backgroundUri ->
                        viewModel.saveOshi(draft, profileUri, backgroundUri) {
                            navController.popBackStack()
                        }
                    },
                )
            }
            composable(
                route = Destination.ItemForm.route,
                arguments = listOf(navArgument("itemId") { type = NavType.StringType }),
            ) { entry ->
                val itemId = entry.arguments?.getString("itemId").orEmpty()
                ItemFormScreen(
                    selectedOshi = uiState.selectedOshi,
                    existing = uiState.items.firstOrNull { it.id == itemId },
                    isSaving = uiState.isWorking,
                    onBack = { navController.popBackStack() },
                    onSave = { draft, imageUri ->
                        viewModel.saveItem(draft, imageUri) {
                            navController.popBackStack()
                        }
                    },
                )
            }
            composable(
                route = Destination.ItemDetail.route,
                arguments = listOf(navArgument("itemId") { type = NavType.StringType }),
            ) { entry ->
                val itemId = entry.arguments?.getString("itemId").orEmpty()
                ItemDetailScreen(
                    item = uiState.items.firstOrNull { it.id == itemId },
                    onBack = { navController.popBackStack() },
                    onEdit = { navController.navigate(Destination.ItemForm.createRoute(it)) },
                    onDelete = { id ->
                        viewModel.deleteItem(id) {
                            navController.popBackStack()
                        }
                    },
                )
            }
            composable(
                route = Destination.LocationForm.route,
                arguments = listOf(navArgument("locationId") { type = NavType.StringType }),
            ) { entry ->
                val locationId = entry.arguments?.getString("locationId").orEmpty()
                LocationFormScreen(
                    selectedOshi = uiState.selectedOshi,
                    existing = uiState.locations.firstOrNull { it.id == locationId },
                    isSaving = uiState.isWorking,
                    onBack = { navController.popBackStack() },
                    onSave = { draft, imageUri ->
                        viewModel.saveLocation(draft, imageUri) {
                            navController.popBackStack()
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun InitializationErrorScreen(
    message: String,
    onRetry: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Surface(
            shape = RoundedCornerShape(28.dp),
            color = Color.White,
            shadowElevation = 8.dp,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    text = "起動に失敗しました",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                )
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
                PrimaryGradientButton(
                    text = "再試行",
                    onClick = onRetry,
                    fullWidth = false,
                    modifier = Modifier.fillMaxWidth(0.7f),
                )
            }
        }
    }
}

@Composable
private fun OshiLogScreen(
    uiState: MainUiState,
    onSelect: (String) -> Unit,
    onAddOshi: () -> Unit,
    onEditOshi: (String) -> Unit,
    onAddItem: () -> Unit,
    onOpenItem: (String) -> Unit,
) {
    val selectedOshi = uiState.selectedOshi
    var searchText by rememberSaveable(selectedOshi?.id) { mutableStateOf("") }
    var selectedItemType by rememberSaveable(selectedOshi?.id) { mutableStateOf(ItemTypeFilterOptions.first()) }
    var selectedCategory by rememberSaveable(selectedOshi?.id) { mutableStateOf(CategoryFilterOptions.first()) }
    var sortOption by rememberSaveable(selectedOshi?.id) { mutableStateOf(SortOptionLabels.first()) }
    var showingFilters by rememberSaveable(selectedOshi?.id) { mutableStateOf(false) }
    val hasActiveFilters = remember(searchText, selectedItemType, selectedCategory, sortOption) {
        searchText.isNotBlank() ||
            selectedItemType != ItemTypeFilterOptions.first() ||
            selectedCategory != CategoryFilterOptions.first() ||
            sortOption != SortOptionLabels.first()
    }
    val filteredItems = remember(
        uiState.items,
        searchText,
        selectedItemType,
        selectedCategory,
        sortOption,
    ) {
        filterLogItems(
            items = uiState.items,
            query = searchText,
            itemType = selectedItemType,
            category = selectedCategory,
            sortOption = sortOption,
        )
    }

    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 116.dp),
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item(span = { GridItemSpan(maxLineSpan) }) {
            if (selectedOshi == null) {
                EmptyOshiHero(onAddOshi = onAddOshi)
            } else {
                SelectedOshiHero(
                    oshi = selectedOshi,
                    itemCount = uiState.items.size,
                    onEdit = { onEditOshi(selectedOshi.id) },
                )
            }
        }

        item(span = { GridItemSpan(maxLineSpan) }) {
            HomeBannerStrip(
                bannerModel = selectedOshi?.backgroundImageUrl ?: R.drawable.test_banner_neon,
            )
        }

        if (selectedOshi != null) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                LogSearchBar(
                    searchText = searchText,
                    onSearchChange = { searchText = it },
                    hasActiveFilters = hasActiveFilters,
                    onToggleFilters = { showingFilters = !showingFilters },
                )
            }
        }

        if (selectedOshi != null && showingFilters) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                CollectionFilterPanel(
                    selectedItemType = selectedItemType,
                    onSelectItemType = { selectedItemType = it },
                    selectedCategory = selectedCategory,
                    onSelectCategory = { selectedCategory = it },
                    sortOption = sortOption,
                    onSelectSort = { sortOption = it },
                )
            }
        }

        if (uiState.oshis.size > 1) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                OshiSelectorRow(
                    oshis = uiState.oshis,
                    selectedOshiId = uiState.userProfile.selectedOshiId,
                    onSelect = onSelect,
                    onAddOshi = onAddOshi,
                )
            }
        }

        if (selectedOshi != null) {
            if (filteredItems.isEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    LogEmptyState(
                        hasSearchQuery = hasActiveFilters,
                        onAddItem = onAddItem,
                    )
                }
            } else {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    CollectionSummaryRow(
                        count = filteredItems.size,
                        sortOption = sortOption,
                    )
                }

                gridItems(filteredItems, key = { it.id }) { item ->
                    LogItemCard(
                        item = item,
                        onClick = { onOpenItem(item.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun EmptyOshiHero(
    onAddOshi: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(296.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(228.dp)
                .background(
                    Brush.linearGradient(
                        colors = listOf(OshiPink, OshiPurple, OshiIndigo),
                    ),
                ),
        )

        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 34.dp, start = 24.dp, end = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box {
                Box(
                    modifier = Modifier
                        .size(110.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.18f))
                        .border(4.dp, Color.White, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Rounded.Face,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(54.dp),
                    )
                }

                Surface(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(52.dp),
                    shape = CircleShape,
                    color = Color.White,
                    tonalElevation = 0.dp,
                    shadowElevation = 8.dp,
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            Icons.Rounded.ChatBubbleOutline,
                            contentDescription = null,
                            tint = OshiPink,
                            modifier = Modifier.size(26.dp),
                        )
                    }
                }
            }
            Text(
                text = "推しを追加",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
            Text(
                text = "最初の推しを登録してホームをはじめましょう",
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White.copy(alpha = 0.88f),
                textAlign = TextAlign.Center,
            )
        }

        Surface(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 22.dp),
            shape = RoundedCornerShape(30.dp),
            color = Color.White,
            shadowElevation = 12.dp,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(
                    text = "最初の推しを登録",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = "プロフィール画像や背景を入れると iOS 版に近い見た目になります。",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
                PrimaryGradientButton(
                    text = "＋ 推しを追加",
                    onClick = onAddOshi,
                    fullWidth = false,
                    modifier = Modifier.fillMaxWidth(0.86f),
                )
            }
        }
    }
}

@Composable
private fun SelectedOshiHero(
    oshi: Oshi,
    itemCount: Int,
    onEdit: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(286.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(226.dp),
        ) {
            if (oshi.backgroundImageUrl.isNullOrBlank()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.linearGradient(
                                colors = listOf(OshiPink, OshiPurple, OshiIndigo),
                            ),
                        ),
                )
            } else {
                AsyncImage(
                    model = oshi.backgroundImageUrl,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Black.copy(alpha = 0.08f),
                                    Color.Black.copy(alpha = 0.45f),
                                ),
                            ),
                    ),
                )
            }
        }

        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 34.dp, start = 24.dp, end = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Box {
                OshiAvatar(
                    imageUrl = oshi.imageUrl,
                    fallbackLabel = oshi.name,
                    modifier = Modifier
                        .size(110.dp)
                        .clickable(onClick = onEdit),
                    borderColor = Color.White,
                )
                Surface(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(52.dp)
                        .clickable(onClick = onEdit),
                    shape = CircleShape,
                    color = Color.White,
                    tonalElevation = 0.dp,
                    shadowElevation = 8.dp,
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            Icons.Rounded.ChatBubbleOutline,
                            contentDescription = "推しを編集",
                            tint = OshiPink,
                            modifier = Modifier.size(26.dp),
                        )
                    }
                }
            }
            Text(
                text = oshi.name,
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
            Text(
                text = if (itemCount == 0) "まだ記録はありません" else "${itemCount}件の記録",
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White.copy(alpha = 0.92f),
            )
        }
    }
}

@Composable
private fun HomeBannerStrip(
    bannerModel: Any,
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 14.dp, bottom = 18.dp),
        shape = RoundedCornerShape(4.dp),
        color = Color.White,
        shadowElevation = 2.dp,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.35f)),
    ) {
        AsyncImage(
            model = bannerModel,
            contentDescription = "バナー",
            modifier = Modifier
                .fillMaxWidth()
                .height(58.dp),
            contentScale = ContentScale.Crop,
        )
    }
}

@Composable
private fun OshiSelectorRow(
    oshis: List<Oshi>,
    selectedOshiId: String?,
    onSelect: (String) -> Unit,
    onAddOshi: () -> Unit,
) {
    Column(
        modifier = Modifier.padding(top = 8.dp, bottom = 8.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = "推しを切り替える",
            modifier = Modifier.padding(horizontal = 24.dp),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        LazyRow(
            contentPadding = PaddingValues(horizontal = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(oshis, key = { it.id }) { oshi ->
                val isSelected = selectedOshiId == oshi.id
                Card(
                    modifier = Modifier.clickable { onSelect(oshi.id) },
                    shape = RoundedCornerShape(999.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (isSelected) OshiSurfaceAlt else MaterialTheme.colorScheme.surface,
                    ),
                    border = BorderStroke(
                        width = 1.dp,
                        color = if (isSelected) OshiPink else MaterialTheme.colorScheme.outline.copy(alpha = 0.55f),
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = if (isSelected) 4.dp else 1.dp),
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        OshiAvatar(
                            imageUrl = oshi.imageUrl,
                            fallbackLabel = oshi.name,
                            modifier = Modifier.size(34.dp),
                            borderColor = if (isSelected) OshiPink else Color.White,
                            borderWidth = if (isSelected) 2.dp else 0.dp,
                        )
                        Text(
                            text = oshi.name,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                    }
                }
            }

            item {
                Card(
                    modifier = Modifier.clickable(onClick = onAddOshi),
                    shape = RoundedCornerShape(999.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(34.dp)
                                .clip(CircleShape)
                                .background(Brush.linearGradient(listOf(OshiPink, OshiPurple))),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                Icons.Rounded.Add,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                        Text(
                            text = "追加",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun LogSearchBar(
    searchText: String,
    onSearchChange: (String) -> Unit,
    hasActiveFilters: Boolean,
    onToggleFilters: () -> Unit,
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp),
        color = Color.White,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp, bottom = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Rounded.Search,
                    contentDescription = null,
                    tint = OshiTextMuted,
                modifier = Modifier.size(38.dp),
            )
            BasicTextField(
                value = searchText,
                onValueChange = onSearchChange,
                modifier = Modifier.weight(1f),
                singleLine = true,
                cursorBrush = SolidColor(OshiPink),
                textStyle = MaterialTheme.typography.headlineSmall.copy(
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.Normal,
                ),
                decorationBox = { innerTextField ->
                    if (searchText.isBlank()) {
                        Text(
                            text = "推しの名前、グッズ名で検索",
                            style = MaterialTheme.typography.headlineSmall,
                            color = OshiTextMuted,
                        )
                    }
                    innerTextField()
                },
            )
            Surface(
                modifier = Modifier.clickable(onClick = onToggleFilters),
                shape = RoundedCornerShape(14.dp),
                color = if (hasActiveFilters) OshiPink.copy(alpha = 0.12f) else Color.Transparent,
            ) {
                Box(
                    modifier = Modifier.padding(6.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Rounded.Tune,
                        contentDescription = "フィルター",
                        tint = OshiPink,
                        modifier = Modifier.size(30.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun CollectionFilterPanel(
    selectedItemType: String,
    onSelectItemType: (String) -> Unit,
    selectedCategory: String,
    onSelectCategory: (String) -> Unit,
    sortOption: String,
    onSelectSort: (String) -> Unit,
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        shape = RoundedCornerShape(28.dp),
        color = Color.White,
        shadowElevation = 8.dp,
    ) {
        Column(
            modifier = Modifier.padding(vertical = 18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            FilterChipSection(
                title = "投稿タイプ",
                options = ItemTypeFilterOptions,
                selected = selectedItemType,
                onSelected = onSelectItemType,
            )
            FilterChipSection(
                title = "並び替え",
                options = SortOptionLabels,
                selected = sortOption,
                onSelected = onSelectSort,
            )
            FilterChipSection(
                title = "カテゴリー",
                options = CategoryFilterOptions,
                selected = selectedCategory,
                onSelected = onSelectCategory,
            )
        }
    }
}

@Composable
private fun FilterChipSection(
    title: String,
    options: List<String>,
    selected: String,
    onSelected: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = title,
            modifier = Modifier.padding(horizontal = 20.dp),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        LazyRow(
            contentPadding = PaddingValues(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(options) { option ->
                val isSelected = selected == option
                Surface(
                    modifier = Modifier.clickable { onSelected(option) },
                    shape = RoundedCornerShape(999.dp),
                    color = if (isSelected) OshiPink else OshiSurfaceAlt,
                    border = BorderStroke(
                        1.dp,
                        if (isSelected) OshiPink else MaterialTheme.colorScheme.outline.copy(alpha = 0.4f),
                    ),
                ) {
                    Text(
                        text = option,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 9.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun CollectionSummaryRow(
    count: Int,
    sortOption: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "投稿一覧",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "${count}件 ・ $sortOption",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun LogEmptyState(
    hasSearchQuery: Boolean,
    onAddItem: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 28.dp, vertical = 34.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Box(modifier = Modifier.size(160.dp), contentAlignment = Alignment.Center) {
            Surface(
                modifier = Modifier
                    .size(86.dp)
                    .align(Alignment.TopStart),
                shape = RoundedCornerShape(26.dp),
                color = OshiPink.copy(alpha = 0.14f),
            ) {}
            Surface(
                modifier = Modifier
                    .size(96.dp)
                    .align(Alignment.BottomEnd),
                shape = RoundedCornerShape(28.dp),
                color = OshiPink.copy(alpha = 0.10f),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        Icons.Rounded.Star,
                        contentDescription = null,
                        tint = OshiPink.copy(alpha = 0.55f),
                        modifier = Modifier.size(48.dp),
                    )
                }
            }
        }

        Text(
            text = if (hasSearchQuery) "該当する記録がありません" else "推しの記録がありません",
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Text(
            text = if (hasSearchQuery) {
                "検索条件を変えるか、新しい記録を追加してみましょう。"
            } else {
                "右下の「+」ボタンから推しグッズやSNS投稿を追加してみましょう！"
            },
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )

        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            PrimaryGradientButton(
                text = "＋ 推しアイテムを追加",
                onClick = onAddItem,
                fullWidth = false,
                modifier = Modifier.fillMaxWidth(0.78f),
            )
        }
    }
}

@Composable
private fun LogItemCard(
    item: OshiItem,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
    ) {
        Column {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1f)
                    .background(
                        if (item.imageUrl.isNullOrBlank()) {
                            Brush.linearGradient(
                                colors = listOf(OshiPink.copy(alpha = 0.25f), OshiPurple.copy(alpha = 0.18f)),
                            )
                        } else {
                            Brush.linearGradient(colors = listOf(Color.Transparent, Color.Transparent))
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                if (item.imageUrl.isNullOrBlank()) {
                    Icon(
                        imageVector = itemTypeIcon(item.itemType.orEmpty()),
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(30.dp),
                    )
                } else {
                    AsyncImage(
                        model = item.imageUrl,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                    )
                }

                item.itemType?.takeIf { it.isNotBlank() }?.let { itemType ->
                    ItemTypeBadge(
                        itemType = itemType,
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(8.dp),
                    )
                }
            }

            Column(
                modifier = Modifier.padding(10.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = item.title ?: "タイトル未設定",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = formatItemDate(item),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    item.favorite?.takeIf { it > 0 }?.let { favorite ->
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(2.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                Icons.Rounded.Favorite,
                                contentDescription = null,
                                tint = OshiPink,
                                modifier = Modifier.size(12.dp),
                            )
                            Text(
                                text = favorite.toString(),
                                style = MaterialTheme.typography.bodySmall,
                                color = OshiPink,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ItemTypeBadge(
    itemType: String,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(999.dp),
        color = itemTypeColor(itemType),
        shadowElevation = 2.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = itemTypeIcon(itemType),
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(10.dp),
            )
            Text(
                text = itemType,
                style = MaterialTheme.typography.labelSmall,
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun FavoriteHeartsRow(
    favoriteCount: Int,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(favoriteCount) {
            Icon(
                Icons.Rounded.Favorite,
                contentDescription = null,
                tint = OshiPink,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

@Composable
private fun ItemDetailScreen(
    item: OshiItem?,
    onBack: () -> Unit,
    onEdit: (String) -> Unit,
    onDelete: (String) -> Unit,
) {
    if (item == null) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            EmptyStateCard(
                title = "投稿が見つかりません",
                body = "一覧に戻ってもう一度選択してください。",
                modifier = Modifier.padding(24.dp),
            )
        }
        return
    }

    val context = LocalContext.current
    var showDeleteDialog by rememberSaveable(item.id) { mutableStateOf(false) }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        onDelete(item.id)
                    },
                ) {
                    Text("削除", color = OshiPink)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("キャンセル")
                }
            },
            title = { Text("投稿を削除") },
            text = { Text("この投稿を削除しますか？") },
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier.weight(1f),
                contentAlignment = Alignment.CenterStart,
            ) {
                TextButton(onClick = onBack, contentPadding = PaddingValues(horizontal = 4.dp, vertical = 6.dp)) {
                    Icon(
                        Icons.AutoMirrored.Rounded.ArrowBack,
                        contentDescription = "戻る",
                        tint = OshiPink,
                    )
                    Text("戻る", color = OshiPink, style = MaterialTheme.typography.headlineSmall)
                }
            }
            Box(
                modifier = Modifier.weight(1.6f),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "投稿詳細",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
            Box(
                modifier = Modifier.weight(1f),
                contentAlignment = Alignment.CenterEnd,
            ) {
                TextButton(
                    onClick = { onEdit(item.id) },
                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 6.dp),
                ) {
                    Text("編集", color = OshiPink, style = MaterialTheme.typography.headlineSmall)
                }
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 36.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(300.dp)
                        .background(OshiSurfaceAlt),
                ) {
                    if (item.imageUrl.isNullOrBlank()) {
                        Icon(
                            imageVector = itemTypeIcon(item.itemType.orEmpty()),
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier
                                .align(Alignment.Center)
                                .size(54.dp),
                        )
                    } else {
                        AsyncImage(
                            model = item.imageUrl,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop,
                        )
                    }
                }
            }

            item {
                Column(
                    modifier = Modifier.padding(horizontal = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(18.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        item.itemType?.takeIf { it.isNotBlank() }?.let {
                            ItemTypeBadge(itemType = it)
                        }
                        item.favorite?.takeIf { it > 0 }?.let {
                            FavoriteHeartsRow(favoriteCount = it)
                        }
                    }

                    Text(
                        text = item.title ?: "タイトル未設定",
                        style = MaterialTheme.typography.headlineLarge,
                        fontWeight = FontWeight.Bold,
                    )

                    item.tags?.takeIf { it.isNotEmpty() }?.let { tags ->
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(tags) { tag ->
                                Surface(
                                    shape = RoundedCornerShape(999.dp),
                                    color = OshiPurple.copy(alpha = 0.1f),
                                ) {
                                    Text(
                                        text = "#$tag",
                                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = OshiPurple,
                                        fontWeight = FontWeight.Medium,
                                    )
                                }
                            }
                        }
                    }

                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.35f))

                    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        item.category?.takeIf { it.isNotBlank() }?.let {
                            ItemDetailInfoRow(label = "カテゴリー", value = it)
                        }
                        item.eventName?.takeIf { it.isNotBlank() }?.let {
                            ItemDetailInfoRow(label = "イベント名", value = it)
                        }
                        item.price?.let {
                            ItemDetailInfoRow(label = "価格", value = formatPrice(it))
                        }
                        displayItemDate(item)?.let { (label, value) ->
                            ItemDetailInfoRow(label = label, value = value)
                        }
                        item.location?.takeIf { it.isNotBlank() }?.let {
                            ItemDetailInfoRow(label = "購入場所", value = it)
                        }
                        item.locationAddress?.takeIf { it.isNotBlank() }?.let {
                            ItemDetailInfoRow(label = "住所", value = it)
                        }
                        item.details?.takeIf { it.isNotBlank() }?.let {
                            ItemDetailInfoRow(label = "詳細", value = it)
                        }
                    }

                    item.memo?.takeIf { it.isNotBlank() }?.let { memo ->
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = memoLabelForItemType(item.itemType),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Surface(
                                shape = RoundedCornerShape(18.dp),
                                color = OshiSurfaceAlt,
                            ) {
                                Text(
                                    text = memo,
                                    modifier = Modifier.padding(18.dp),
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurface,
                                )
                            }
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        DetailActionButton(
                            modifier = Modifier.weight(1f),
                            text = "共有",
                            borderColor = OshiIndigo,
                            contentColor = OshiIndigo,
                            onClick = { shareItem(context, item) },
                        )
                        DetailActionButton(
                            modifier = Modifier.weight(1f),
                            text = "編集",
                            borderColor = OshiPink,
                            contentColor = OshiPink,
                            onClick = { onEdit(item.id) },
                        )
                        DetailActionButton(
                            modifier = Modifier.weight(1f),
                            text = "削除",
                            borderColor = OshiPink.copy(alpha = 0.5f),
                            contentColor = OshiPink,
                            icon = Icons.Rounded.Delete,
                            onClick = { showDeleteDialog = true },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ItemDetailInfoRow(
    label: String,
    value: String,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.Medium,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun DetailActionButton(
    text: String,
    borderColor: Color,
    contentColor: Color,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    onClick: () -> Unit,
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.height(54.dp),
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, borderColor),
        colors = ButtonDefaults.outlinedButtonColors(contentColor = contentColor),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            icon?.let {
                Icon(it, contentDescription = null, modifier = Modifier.size(16.dp))
            }
            Text(text, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun OshiAvatar(
    imageUrl: String?,
    fallbackLabel: String,
    modifier: Modifier = Modifier,
    borderColor: Color = Color.White,
    borderWidth: androidx.compose.ui.unit.Dp = 4.dp,
) {
    Box(
        modifier = modifier
            .clip(CircleShape)
            .background(Brush.linearGradient(listOf(OshiPink, OshiPurple)))
            .then(
                if (borderWidth > 0.dp) Modifier.border(borderWidth, borderColor, CircleShape) else Modifier
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (imageUrl.isNullOrBlank()) {
            Text(
                text = fallbackLabel.firstOrNull()?.toString() ?: "推",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
        } else {
            AsyncImage(
                model = imageUrl,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
    }
}

@Composable
private fun PrimaryGradientButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    fullWidth: Boolean = true,
    gradientColors: List<Color> = listOf(OshiPink, OshiPurple),
) {
    Button(
        onClick = onClick,
        modifier = if (fullWidth) {
            modifier
                .fillMaxWidth()
                .height(58.dp)
        } else {
            modifier.height(58.dp)
        },
        shape = RoundedCornerShape(999.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Transparent,
            contentColor = Color.White,
        ),
        contentPadding = PaddingValues(),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.horizontalGradient(gradientColors),
                    shape = RoundedCornerShape(999.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
        }
    }
}

@Composable
private fun ItemsScreen(
    uiState: MainUiState,
    onEdit: (String) -> Unit,
) {
    val selectedOshi = uiState.selectedOshi
    if (selectedOshi == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EmptyStateCard(
                title = "推しが未選択です",
                body = "先に推しタブで推しを追加または選択してください。",
                modifier = Modifier.padding(16.dp),
            )
        }
        return
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            SectionCard {
                Text(text = "投稿", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(text = "${selectedOshi.name} に紐づく投稿を一覧表示しています。")
            }
        }
        if (uiState.items.isEmpty()) {
            item {
                EmptyStateCard(
                    title = "投稿がまだありません",
                    body = "右下の追加ボタンから最初の投稿を登録してください。",
                )
            }
        } else {
            items(uiState.items, key = { it.id }) { item ->
                ItemCard(item = item, onClick = { onEdit(item.id) })
            }
        }
    }
}

@Composable
private fun ItemCard(
    item: OshiItem,
    onClick: () -> Unit,
) {
    ElevatedCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(24.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(RoundedCornerShape(18.dp)),
                contentAlignment = Alignment.Center,
            ) {
                if (item.imageUrl.isNullOrBlank()) {
                    Surface(modifier = Modifier.fillMaxSize()) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.Rounded.PostAdd, contentDescription = null)
                        }
                    }
                } else {
                    AsyncImage(
                        model = item.imageUrl,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                    )
                }
            }

            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = item.title ?: "タイトル未設定",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Text(text = item.itemType ?: "種類未設定", style = MaterialTheme.typography.labelLarge)
                Text(
                    text = item.memo ?: item.details ?: item.locationAddress ?: "タップして詳細を編集",
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun PlacesScreen(
    uiState: MainUiState,
    onEdit: (String) -> Unit,
) {
    val selectedOshi = uiState.selectedOshi
    if (selectedOshi == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EmptyStateCard(
                title = "推しが未選択です",
                body = "先に推しタブで推しを追加または選択してください。",
                modifier = Modifier.padding(16.dp),
            )
        }
        return
    }

    var selectedLocationId by rememberSaveable(selectedOshi.id) {
        mutableStateOf(uiState.locations.firstOrNull()?.id)
    }
    var selectedCategories by remember(selectedOshi.id) {
        mutableStateOf<Set<String>>(emptySet())
    }

    val visibleLocations = remember(uiState.locations, selectedCategories) {
        if (selectedCategories.isEmpty()) {
            uiState.locations
        } else {
            uiState.locations.filter { it.category in selectedCategories }
        }
    }

    LaunchedEffect(visibleLocations) {
        if (selectedLocationId == null || visibleLocations.none { it.id == selectedLocationId }) {
            selectedLocationId = visibleLocations.firstOrNull()?.id
        }
    }

    val selectedLocation = visibleLocations.firstOrNull { it.id == selectedLocationId }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .clip(RoundedCornerShape(34.dp))
                .background(Color.White),
        ) {
            LeafletMapView(
                locations = visibleLocations,
                selectedLocationId = selectedLocationId,
                modifier = Modifier.fillMaxSize(),
                onSelect = { selectedLocationId = it },
            )
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .height(188.dp)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(Color.White.copy(alpha = 0.9f), Color.Transparent),
                        ),
                    ),
            )

            Column(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(start = 20.dp, top = 22.dp, end = 96.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(
                    text = "聖地巡礼",
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = "${selectedOshi.name} のスポットを地図で見る",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    item {
                        MapFilterChip(
                            text = "すべて",
                            isSelected = selectedCategories.isEmpty(),
                            color = OshiBlue,
                            onClick = { selectedCategories = emptySet() },
                        )
                    }
                    items(LocationCategoryOptions) { category ->
                        val isSelected = category in selectedCategories
                        MapFilterChip(
                            text = category,
                            isSelected = isSelected,
                            color = locationCategoryColor(category),
                            onClick = {
                                selectedCategories = if (isSelected) {
                                    selectedCategories - category
                                } else {
                                    selectedCategories + category
                                }
                            },
                        )
                    }
                }
            }

            selectedLocation?.let { location ->
                SelectedLocationBadge(
                    location = location,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 24.dp, end = 18.dp),
                )
            }

            if (visibleLocations.isEmpty()) {
                Surface(
                    modifier = Modifier
                        .align(Alignment.Center)
                        .padding(horizontal = 28.dp),
                    shape = RoundedCornerShape(28.dp),
                    color = Color.White.copy(alpha = 0.96f),
                    shadowElevation = 16.dp,
                ) {
                    Column(
                        modifier = Modifier.padding(horizontal = 24.dp, vertical = 28.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(
                            Icons.Rounded.Place,
                            contentDescription = null,
                            tint = OshiPink,
                            modifier = Modifier.size(34.dp),
                        )
                        Text(
                            text = "スポットがまだありません",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            textAlign = TextAlign.Center,
                        )
                        Text(
                            text = "右下の追加ボタンから最初の聖地巡礼スポットを登録してください。",
                            style = MaterialTheme.typography.bodyLarge,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            Column(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 18.dp, bottom = 18.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                horizontalAlignment = Alignment.End,
            ) {
                MiniFloatingPill(
                    icon = Icons.Rounded.Tune,
                    text = if (selectedCategories.isEmpty()) "絞り込み" else "${selectedCategories.size}件",
                    onClick = { selectedCategories = emptySet() },
                )
                MiniFloatingCircleButton(
                    icon = Icons.Rounded.Place,
                    onClick = { selectedLocationId = visibleLocations.firstOrNull()?.id },
                )
            }
        }

        if (visibleLocations.isNotEmpty()) {
            LazyRow(
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                items(visibleLocations, key = { it.id }) { location ->
                    LocationCard(
                        location = location,
                        isSelected = location.id == selectedLocationId,
                        onSelect = { selectedLocationId = location.id },
                        onEdit = { onEdit(location.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun PlacesMapBackdrop() {
    Box(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .align(Alignment.TopStart)
                .offset(x = 10.dp, y = 64.dp)
                .fillMaxWidth(0.82f)
                .height(220.dp)
                .clip(RoundedCornerShape(220.dp))
                .background(
                    Brush.linearGradient(
                        listOf(
                            OshiPink.copy(alpha = 0.22f),
                            OshiPurple.copy(alpha = 0.18f),
                            OshiBlue.copy(alpha = 0.12f),
                        ),
                    ),
                ),
        )
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = (-18).dp, y = 124.dp)
                .size(132.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.62f)),
        )
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .offset(x = 26.dp, y = (-66).dp)
                .fillMaxWidth(0.58f)
                .height(78.dp)
                .clip(RoundedCornerShape(999.dp))
                .background(Color.White.copy(alpha = 0.45f)),
        )
        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .offset(x = (-24).dp, y = 10.dp)
                .fillMaxWidth(0.14f)
                .height(176.dp)
                .clip(RoundedCornerShape(999.dp))
                .background(Color.White.copy(alpha = 0.42f)),
        )
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(160.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.White.copy(alpha = 0.24f)),
                    ),
                ),
        )
    }
}

@Composable
private fun PlacesMapMarkers(
    locations: List<EventLocation>,
    selectedLocationId: String?,
    onSelect: (String) -> Unit,
) {
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        locations.forEach { location ->
            val (xFraction, yFraction) = mapMarkerFractions(locations, location)
            LocationMapMarker(
                location = location,
                isSelected = location.id == selectedLocationId,
                modifier = Modifier.offset(
                    x = maxWidth * xFraction - 32.dp,
                    y = maxHeight * yFraction - 70.dp,
                ),
                onClick = { onSelect(location.id) },
            )
        }
    }
}

@Composable
private fun LocationMapMarker(
    location: EventLocation,
    isSelected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier.clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        Surface(
            shape = RoundedCornerShape(22.dp),
            color = Color.White.copy(alpha = 0.97f),
            border = BorderStroke(
                if (isSelected) 3.dp else 1.dp,
                if (isSelected) locationCategoryColor(location.category) else Color.White.copy(alpha = 0.85f),
            ),
            shadowElevation = if (isSelected) 18.dp else 8.dp,
        ) {
            Box(
                modifier = Modifier
                    .size(if (isSelected) 72.dp else 60.dp)
                    .clip(RoundedCornerShape(18.dp)),
                contentAlignment = Alignment.Center,
            ) {
                if (location.imageURL.isNullOrBlank()) {
                    Icon(
                        Icons.Rounded.Place,
                        contentDescription = null,
                        tint = locationCategoryColor(location.category),
                        modifier = Modifier.size(28.dp),
                    )
                } else {
                    AsyncImage(
                        model = location.imageURL,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                    )
                }
            }
        }
        Box(
            modifier = Modifier
                .offset(y = (-8).dp)
                .size(if (isSelected) 18.dp else 14.dp)
                .clip(CircleShape)
                .background(locationCategoryColor(location.category))
                .border(3.dp, Color.White, CircleShape),
        )
    }
}

@Composable
private fun SelectedLocationBadge(
    location: EventLocation,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(22.dp),
        color = Color.White.copy(alpha = 0.96f),
        shadowElevation = 10.dp,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(locationCategoryColor(location.category)),
                )
                Text(
                    text = location.category,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = location.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

@Composable
private fun MapFilterChip(
    text: String,
    isSelected: Boolean,
    color: Color,
    onClick: () -> Unit,
) {
    Surface(
        modifier = Modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(999.dp),
        color = if (isSelected) color.copy(alpha = 0.14f) else Color.White.copy(alpha = 0.78f),
        border = BorderStroke(1.dp, if (isSelected) color else Color.White.copy(alpha = 0.55f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(color),
            )
            Text(
                text = text,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                color = if (isSelected) color else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun MiniFloatingPill(
    icon: ImageVector,
    text: String,
    onClick: () -> Unit,
) {
    Surface(
        modifier = Modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(999.dp),
        color = Color.White.copy(alpha = 0.96f),
        shadowElevation = 8.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(icon, contentDescription = null, tint = OshiPink, modifier = Modifier.size(18.dp))
            Text(text = text, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun MiniFloatingCircleButton(
    icon: ImageVector,
    onClick: () -> Unit,
) {
    Surface(
        modifier = Modifier.clickable(onClick = onClick),
        shape = CircleShape,
        color = Color.White.copy(alpha = 0.96f),
        shadowElevation = 8.dp,
    ) {
        Box(
            modifier = Modifier.size(48.dp),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = OshiBlue, modifier = Modifier.size(22.dp))
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun LeafletMapView(
    locations: List<EventLocation>,
    selectedLocationId: String?,
    modifier: Modifier = Modifier,
    onSelect: (String) -> Unit,
) {
    val latestOnSelect by rememberUpdatedState(onSelect)
    val html = remember(locations) { buildLeafletHtml(locations) }
    val bridge = remember { LeafletBridge() }

    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.cacheMode = WebSettings.LOAD_DEFAULT
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                overScrollMode = WebView.OVER_SCROLL_NEVER
                isVerticalScrollBarEnabled = false
                isHorizontalScrollBarEnabled = false
                webChromeClient = WebChromeClient()
                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        super.onPageFinished(view, url)
                        val focusId = selectedLocationId ?: locations.firstOrNull()?.id
                        focusId?.let { id ->
                            view?.evaluateJavascript("window.focusMarker(${JSONObject.quote(id)});", null)
                        }
                    }
                }
                bridge.onSelect = { latestOnSelect(it) }
                addJavascriptInterface(bridge, "AndroidBridge")
                loadDataWithBaseURL("https://localhost/", html, "text/html", "UTF-8", null)
                tag = html
            }
        },
        update = { webView ->
            bridge.onSelect = { latestOnSelect(it) }
            if (webView.tag != html) {
                webView.loadDataWithBaseURL("https://localhost/", html, "text/html", "UTF-8", null)
                webView.tag = html
            }
            val focusId = selectedLocationId ?: locations.firstOrNull()?.id
            if (focusId != null) {
                webView.evaluateJavascript("window.focusMarker(${JSONObject.quote(focusId)});", null)
            }
        },
    )
}

private class LeafletBridge {
    private val handler = Handler(Looper.getMainLooper())
    var onSelect: (String) -> Unit = {}

    @JavascriptInterface
    fun handleMarkerTap(locationId: String) {
        handler.post { onSelect(locationId) }
    }
}

private fun buildLeafletHtml(locations: List<EventLocation>): String {
    val markerData = JSONArray().apply {
        locations.forEach { location ->
            put(
                JSONObject().apply {
                    put("id", location.id)
                    put("title", location.title)
                    put("category", location.category)
                    put("lat", location.latitude)
                    put("lng", location.longitude)
                    put("color", locationCategoryColorHex(location.category))
                },
            )
        }
    }

    return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
          <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
          <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
          <style>
            html, body, #map {
              margin: 0;
              padding: 0;
              width: 100%;
              height: 100%;
              background: #f8f7fb;
            }
            .leaflet-control-attribution {
              font-size: 8px;
              background: rgba(255,255,255,0.75);
            }
            .custom-pin {
              background: transparent;
              border: none;
            }
            .pin-wrap {
              display: flex;
              flex-direction: column;
              align-items: center;
            }
            .pin-head {
              border-radius: 999px;
              box-shadow: 0 8px 20px rgba(0,0,0,0.18);
            }
            .pin-tail {
              width: 0;
              height: 0;
              margin-top: -2px;
              border-left: 8px solid transparent;
              border-right: 8px solid transparent;
              border-top: 12px solid #ff6b9d;
              filter: drop-shadow(0 3px 4px rgba(0,0,0,0.15));
            }
          </style>
        </head>
        <body>
          <div id="map"></div>
          <script>
            const markersData = $markerData;
            const map = L.map('map', {
              zoomControl: false,
              attributionControl: true
            }).setView([35.6809591, 139.7673068], 13);

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
              maxZoom: 19,
              attribution: '&copy; OpenStreetMap'
            }).addTo(map);

            const markersById = {};
            let selectedId = null;

            function makeIcon(color, selected) {
              const size = selected ? 30 : 24;
              const border = selected ? 4 : 3;
              return L.divIcon({
                className: 'custom-pin',
                html: `
                  <div class="pin-wrap">
                    <div class="pin-head" style="width:${'$'}{size}px;height:${'$'}{size}px;background:${'$'}{color};border:${'$'}{border}px solid white;"></div>
                    <div class="pin-tail" style="border-top-color:${'$'}{color}"></div>
                  </div>
                `,
                iconSize: [36, 48],
                iconAnchor: [18, 44]
              });
            }

            function updateSelection(nextId) {
              selectedId = nextId;
              Object.values(markersById).forEach(({ marker, color, id }) => {
                marker.setIcon(makeIcon(color, id === selectedId));
              });
            }

            function focusMarker(id) {
              if (!markersById[id]) return;
              updateSelection(id);
              const marker = markersById[id].marker;
              map.flyTo(marker.getLatLng(), Math.max(map.getZoom(), 15), { duration: 0.35 });
            }

            window.focusMarker = focusMarker;

            markersData.forEach((item) => {
              const marker = L.marker([item.lat, item.lng], {
                icon: makeIcon(item.color, false)
              }).addTo(map);
              marker.on('click', () => {
                focusMarker(item.id);
                if (window.AndroidBridge && window.AndroidBridge.handleMarkerTap) {
                  window.AndroidBridge.handleMarkerTap(item.id);
                }
              });
              markersById[item.id] = { marker, color: item.color, id: item.id };
            });

            if (markersData.length === 1) {
              focusMarker(markersData[0].id);
            } else if (markersData.length > 1) {
              const bounds = L.latLngBounds(markersData.map(item => [item.lat, item.lng]));
              map.fitBounds(bounds.pad(0.32));
            }
          </script>
        </body>
        </html>
    """.trimIndent()
}

private fun locationCategoryColorHex(category: String): String = when (category) {
    "聖地巡礼" -> "#EF4444"
    "撮影スポット" -> "#FF6B9D"
    "カフェ・飲食店" -> "#10B981"
    "ライブ会場" -> "#0A84FF"
    "グッズショップ" -> "#F59E0B"
    else -> "#C44AFF"
}

@Composable
private fun ChatPlaceholderScreen(
    uiState: MainUiState,
) {
    PlaceholderTabScreen(
        title = "チャット",
        subtitle = uiState.selectedOshi?.name?.let { "$it と話せる画面" } ?: "推しとの個別チャット",
        body = "iOS版に合わせるためのタブ位置は再現しています。チャット画面そのものは次の段階で移植対象です。",
        icon = Icons.Rounded.ChatBubbleOutline,
    )
}

@Composable
private fun GroupPlaceholderScreen(
    uiState: MainUiState,
) {
    PlaceholderTabScreen(
        title = "グループチャット",
        subtitle = "推し仲間との会話スペース",
        body = if (uiState.selectedOshi != null) {
            "${uiState.selectedOshi?.name} まわりのグループ会話導線をここへ寄せています。"
        } else {
            "iOS版と同じ5タブ構成へ近づけるため、タブ位置を先に合わせています。"
        },
        icon = Icons.Rounded.Groups,
    )
}

@Composable
private fun PlaceholderTabScreen(
    title: String,
    subtitle: String,
    body: String,
    icon: ImageVector,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = 24.dp, vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size(108.dp)
                .clip(CircleShape)
                .background(Brush.linearGradient(listOf(OshiPink.copy(alpha = 0.18f), OshiPurple.copy(alpha = 0.18f)))),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                icon,
                contentDescription = null,
                modifier = Modifier.size(46.dp),
                tint = OshiPink,
            )
        }
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = subtitle,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = body,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun LocationCard(
    location: EventLocation,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onEdit: () -> Unit,
) {
    ElevatedCard(
        modifier = Modifier
            .width(308.dp)
            .clickable(onClick = onSelect),
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = if (isSelected) Color.White else Color.White.copy(alpha = 0.96f),
        ),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = if (isSelected) 14.dp else 8.dp),
    ) {
        Column(
            modifier = Modifier
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(122.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .background(locationCategoryColor(location.category).copy(alpha = 0.08f)),
            ) {
                if (location.imageURL.isNullOrBlank()) {
                    Icon(
                        Icons.Rounded.Place,
                        contentDescription = null,
                        tint = locationCategoryColor(location.category),
                        modifier = Modifier
                            .align(Alignment.Center)
                            .size(34.dp),
                    )
                } else {
                    AsyncImage(
                        model = location.imageURL,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                    )
                }

                Surface(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(12.dp),
                    shape = RoundedCornerShape(999.dp),
                    color = Color.White.copy(alpha = 0.92f),
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(locationCategoryColor(location.category)),
                        )
                        Text(location.category, style = MaterialTheme.typography.labelMedium)
                    }
                }
            }

            Text(
                text = location.title,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = location.locationAddress ?: "${location.latitude}, ${location.longitude}",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            location.note?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "緯度 ${"%.4f".format(location.latitude)} / 経度 ${"%.4f".format(location.longitude)}",
                    style = MaterialTheme.typography.labelMedium,
                    color = OshiTextMuted,
                )
                Spacer(modifier = Modifier.weight(1f))
                TextButton(onClick = onEdit) {
                    Text("編集", color = OshiPink, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun SettingsScreen(
    uiState: MainUiState,
    onSave: (String, String) -> Unit,
) {
    var username by rememberSaveable { mutableStateOf(uiState.userProfile.username.orEmpty()) }
    var favoriteOshi by rememberSaveable { mutableStateOf(uiState.userProfile.favoriteOshi.orEmpty()) }

    LaunchedEffect(uiState.userProfile.username, uiState.userProfile.favoriteOshi) {
        username = uiState.userProfile.username.orEmpty()
        favoriteOshi = uiState.userProfile.favoriteOshi.orEmpty()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SectionCard {
            Text(text = "設定", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            DetailRow(label = "UID", value = uiState.userId ?: "-")
            DetailRow(label = "選択中の推し", value = uiState.selectedOshi?.name ?: "なし")
        }

        SectionCard {
            Text(text = "プロフィール", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            OutlinedTextField(
                value = username,
                onValueChange = { username = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("ユーザー名") },
            )
            OutlinedTextField(
                value = favoriteOshi,
                onValueChange = { favoriteOshi = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("好きな推し") },
            )
            Button(
                onClick = { onSave(username, favoriteOshi) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("プロフィールを保存")
            }
        }

        SectionCard {
            Text(text = "メモ", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(
                text = "このMVPでは iOS と Android は別UIDのまま運用できます。Firebase Realtime Database と Storage は同じ設計で保存します。",
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun FormSectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.headlineMedium,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun SoftInputField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true,
    minLines: Int = 1,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = OshiSurfaceAlt,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.45f)),
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp, vertical = 16.dp),
            singleLine = singleLine,
            minLines = minLines,
            cursorBrush = SolidColor(OshiPink),
            keyboardOptions = KeyboardOptions.Default.copy(keyboardType = keyboardType),
            textStyle = MaterialTheme.typography.bodyLarge.copy(
                color = MaterialTheme.colorScheme.onSurface,
            ),
            decorationBox = { innerTextField ->
                if (value.isBlank()) {
                    Text(
                        text = placeholder,
                        style = MaterialTheme.typography.bodyLarge,
                        color = OshiTextMuted,
                    )
                }
                innerTextField()
            },
        )
    }
}

@Composable
private fun WhiteCardInputField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true,
    minLines: Int = 1,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        color = Color.White,
        shadowElevation = 6.dp,
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 15.dp),
            singleLine = singleLine,
            minLines = minLines,
            cursorBrush = SolidColor(OshiBlue),
            keyboardOptions = KeyboardOptions.Default.copy(keyboardType = keyboardType),
            textStyle = MaterialTheme.typography.bodyLarge.copy(
                color = MaterialTheme.colorScheme.onSurface,
            ),
            decorationBox = { innerTextField ->
                if (value.isBlank()) {
                    Text(
                        text = placeholder,
                        style = MaterialTheme.typography.bodyLarge,
                        color = OshiTextMuted,
                    )
                }
                innerTextField()
            },
        )
    }
}

@Composable
private fun FormImagePickerCard(
    model: Any?,
    placeholderIcon: ImageVector,
    placeholderText: String,
    modifier: Modifier = Modifier,
    accentColor: Color = OshiPink,
    onClick: () -> Unit,
) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .height(220.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(24.dp),
        color = OshiSurfaceAlt,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.35f)),
    ) {
        if (model == null) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Icon(
                        imageVector = placeholderIcon,
                        contentDescription = null,
                        modifier = Modifier.size(58.dp),
                        tint = accentColor.copy(alpha = 0.85f),
                    )
                    Text(
                        text = placeholderText,
                        style = MaterialTheme.typography.headlineSmall,
                        color = OshiTextMuted,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        } else {
            AsyncImage(
                model = model,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
    }
}

private fun createTestImageUri(
    context: Context,
    preset: TestImagePreset,
): Uri {
    val drawable = requireNotNull(AppCompatResources.getDrawable(context, preset.drawableRes)) {
        "Missing drawable resource: ${preset.drawableRes}"
    }
    val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: 1080
    val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: 1080
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    drawable.setBounds(0, 0, canvas.width, canvas.height)
    drawable.draw(canvas)

    val directory = File(context.cacheDir, "test-images").apply { mkdirs() }
    val file = File(directory, preset.cacheFileName)
    FileOutputStream(file).use { output ->
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
    }
    return file.toUri()
}

@Composable
private fun TestImagePresetRow(
    presets: List<TestImagePreset>,
    onSelect: (Uri) -> Unit,
) {
    val context = LocalContext.current

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = "すぐ使えるテスト画像",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            items(presets) { preset ->
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Surface(
                        modifier = Modifier
                            .size(width = 124.dp, height = 82.dp)
                            .clickable { onSelect(createTestImageUri(context, preset)) },
                        shape = RoundedCornerShape(18.dp),
                        tonalElevation = 0.dp,
                        shadowElevation = 0.dp,
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.28f)),
                        color = MaterialTheme.colorScheme.surface,
                    ) {
                        AsyncImage(
                            model = preset.drawableRes,
                            contentDescription = preset.label,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop,
                        )
                    }
                    Text(
                        text = preset.label,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun ProfileImagePicker(
    model: Any?,
    onClick: () -> Unit,
    accentColor: Color = OshiPink,
    helperText: String = "タップしてプロフィール画像を選択",
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box {
            Box(
                modifier = Modifier
                    .size(128.dp)
                    .clip(CircleShape)
                    .background(OshiSurfaceAlt)
                    .border(3.dp, accentColor, CircleShape)
                    .clickable(onClick = onClick),
                contentAlignment = Alignment.Center,
            ) {
                if (model == null) {
                    Icon(
                        Icons.Rounded.Face,
                        contentDescription = null,
                        modifier = Modifier.size(52.dp),
                        tint = accentColor,
                    )
                } else {
                    AsyncImage(
                        model = model,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                    )
                }
            }

            Surface(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .size(34.dp),
                shape = CircleShape,
                color = accentColor,
                shadowElevation = 6.dp,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        Icons.Rounded.Edit,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
        }
        Text(
            text = helperText,
            style = MaterialTheme.typography.bodyMedium,
            color = OshiTextMuted,
        )
    }
}

@Composable
private fun SegmentedOptionRow(
    selected: String,
    options: List<String>,
    onSelected: (String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(12.dp))
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            Surface(
                modifier = Modifier
                    .weight(1f)
                    .clickable { onSelected(option) },
                shape = RoundedCornerShape(10.dp),
                color = if (isSelected) OshiBlue.copy(alpha = 0.12f) else Color.Transparent,
            ) {
                Box(
                    modifier = Modifier.padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = option,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (isSelected) OshiBlue else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun SelectableTypeRow(
    selected: String,
    options: List<String>,
    onSelected: (String) -> Unit,
) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        items(options) { option ->
            val isSelected = selected == option
            Surface(
                modifier = Modifier
                    .size(width = 96.dp, height = 96.dp)
                    .clickable { onSelected(option) },
                shape = RoundedCornerShape(18.dp),
                color = if (isSelected) OshiPink.copy(alpha = 0.08f) else MaterialTheme.colorScheme.surface,
                border = BorderStroke(
                    2.dp,
                    if (isSelected) OshiPink else MaterialTheme.colorScheme.outline.copy(alpha = 0.35f),
                ),
                tonalElevation = 0.dp,
                shadowElevation = 0.dp,
            ) {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(
                        imageVector = itemTypeIcon(option),
                        contentDescription = null,
                        tint = if (isSelected) OshiPink else OshiTextMuted,
                        modifier = Modifier.size(30.dp),
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = option,
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (isSelected) OshiPink else MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

@Composable
private fun CapsuleSelectorRow(
    selected: String,
    options: List<String>,
    onSelected: (String) -> Unit,
) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        items(options) { option ->
            val isSelected = selected == option
            Surface(
                modifier = Modifier.clickable { onSelected(option) },
                shape = RoundedCornerShape(999.dp),
                color = if (isSelected) OshiPurple else OshiSurfaceAlt,
            ) {
                Text(
                    text = option,
                    modifier = Modifier.padding(horizontal = 18.dp, vertical = 10.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                )
            }
        }
    }
}

private fun itemTypeIcon(type: String): ImageVector = when (type) {
    "グッズ" -> Icons.Rounded.CardGiftcard
    "聖地巡礼" -> Icons.Rounded.Place
    "ライブ記録" -> Icons.Rounded.MusicNote
    "SNS投稿" -> Icons.Rounded.ChatBubbleOutline
    else -> Icons.Rounded.MoreHoriz
}

private fun itemTypeColor(type: String): Color = when (type) {
    "グッズ" -> OshiPink
    "聖地巡礼" -> Color(0xFF34C759)
    "ライブ記録" -> Color(0xFFFF9F0A)
    "SNS投稿" -> OshiPurple
    else -> Color(0xFF8E8E93)
}

private fun memoLabelForItemType(type: String?): String = when (type) {
    "聖地巡礼" -> "思い出"
    "SNS投稿" -> "投稿メモ"
    else -> "メモ"
}

private fun dateLabelForItemType(type: String): String = when (type) {
    "聖地巡礼" -> "訪問日"
    "ライブ記録" -> "ライブ日"
    "SNS投稿" -> "投稿日"
    "その他" -> "記録日"
    else -> "購入日"
}

private fun resolveItemTimestamp(item: OshiItem?): Double? = item?.purchaseDate ?: item?.visitDate ?: item?.recordDate ?: item?.createdAt

private fun formatDate(timestampSeconds: Double?): String {
    if (timestampSeconds == null) return "未設定"
    return SimpleDateFormat("yyyy/MM/dd", Locale.JAPAN).format(Date((timestampSeconds * 1000).toLong()))
}

private fun formatItemDate(item: OshiItem): String = formatDate(resolveItemTimestamp(item))

private fun displayItemDate(item: OshiItem): Pair<String, String>? {
    val label = when {
        item.visitDate != null -> "訪問日"
        item.recordDate != null && item.itemType == "SNS投稿" -> "投稿日"
        item.recordDate != null -> "記録日"
        item.purchaseDate != null && item.itemType == "ライブ記録" -> "ライブ日"
        item.purchaseDate != null -> "購入日"
        else -> return null
    }
    return label to formatDate(resolveItemTimestamp(item))
}

private fun formatPrice(price: Int): String = NumberFormat.getCurrencyInstance(Locale.JAPAN).format(price)

@Composable
private fun OshiFormScreen(
    existing: Oshi?,
    isSaving: Boolean,
    onBack: () -> Unit,
    onSave: (OshiDraft, Uri?, Uri?) -> Unit,
) {
    var name by remember(existing?.id) { mutableStateOf(existing?.name.orEmpty()) }
    var memo by remember(existing?.id) { mutableStateOf(existing?.memo.orEmpty()) }
    var personality by remember(existing?.id) { mutableStateOf(existing?.personality.orEmpty()) }
    var speakingStyle by remember(existing?.id) { mutableStateOf(existing?.speakingStyle.orEmpty()) }
    var birthday by remember(existing?.id) { mutableStateOf(existing?.birthday.orEmpty()) }
    var height by remember(existing?.id) { mutableStateOf(existing?.height?.toString().orEmpty()) }
    var hometown by remember(existing?.id) { mutableStateOf(existing?.hometown.orEmpty()) }
    var favoriteColor by remember(existing?.id) { mutableStateOf(existing?.favoriteColor.orEmpty()) }
    var favoriteFood by remember(existing?.id) { mutableStateOf(existing?.favoriteFood.orEmpty()) }
    var dislikedFood by remember(existing?.id) { mutableStateOf(existing?.dislikedFood.orEmpty()) }
    var interestsText by remember(existing?.id) { mutableStateOf(existing?.interests?.joinToString("、").orEmpty()) }
    var userNickname by remember(existing?.id) { mutableStateOf(existing?.userNickname.orEmpty()) }
    var relationshipStatus by remember(existing?.id) { mutableStateOf(existing?.relationshipStatus.orEmpty()) }
    var relationshipDetail by remember(existing?.id) { mutableStateOf(existing?.relationshipDetail.orEmpty()) }
    var sharedMemory by remember(existing?.id) { mutableStateOf(existing?.sharedMemory.orEmpty()) }
    var signaturePhrase by remember(existing?.id) { mutableStateOf(existing?.signaturePhrase.orEmpty()) }
    var conversationTopicsText by remember(existing?.id) { mutableStateOf(existing?.conversationTopics?.joinToString("、").orEmpty()) }
    var forbiddenTopicsText by remember(existing?.id) { mutableStateOf(existing?.forbiddenTopics?.joinToString("、").orEmpty()) }
    var gender by remember(existing?.id) { mutableStateOf(existing?.gender ?: OshiGenderOptions.first()) }
    var preferredLanguage by remember(existing?.id) { mutableStateOf(existing?.preferredLanguage ?: OshiLanguageOptions.first()) }
    var profileImageUri by remember(existing?.id) { mutableStateOf<Uri?>(null) }
    var backgroundImageUri by remember(existing?.id) { mutableStateOf<Uri?>(null) }

    val profilePicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) {
        profileImageUri = it
    }
    val backgroundPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) {
        backgroundImageUri = it
    }

    FormScaffold(
        title = if (existing == null) "推しを追加" else "推しを編集",
        actionLabel = if (existing == null) "登録" else "保存",
        onBack = onBack,
        isSaving = isSaving,
        containerColor = Color(0xFFF2F2F7),
        onSave = {
            onSave(
                OshiDraft(
                    id = existing?.id,
                    name = name,
                    memo = memo,
                    personality = personality,
                    speakingStyle = speakingStyle,
                    birthday = birthday,
                    height = height,
                    hometown = hometown,
                    favoriteColor = favoriteColor,
                    favoriteFood = favoriteFood,
                    dislikedFood = dislikedFood,
                    interestsText = interestsText,
                    userNickname = userNickname,
                    relationshipStatus = relationshipStatus,
                    relationshipDetail = relationshipDetail,
                    sharedMemory = sharedMemory,
                    signaturePhrase = signaturePhrase,
                    conversationTopicsText = conversationTopicsText,
                    forbiddenTopicsText = forbiddenTopicsText,
                    gender = gender,
                    preferredLanguage = preferredLanguage,
                ),
                profileImageUri,
                backgroundImageUri,
            )
        },
    ) {
        ProfileImagePicker(
            model = profileImageUri ?: existing?.imageUrl,
            accentColor = OshiBlue,
            helperText = "推しプロフィール画像",
            onClick = {
                profilePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
        )
        TestImagePresetRow(
            presets = OshiProfileTestPresets,
            onSelect = { profileImageUri = it },
        )

        FormSectionTitle("背景画像")
        FormImagePickerCard(
            model = backgroundImageUri ?: existing?.backgroundImageUrl,
            placeholderIcon = Icons.Rounded.Face,
            placeholderText = "タップして背景画像を選択",
            accentColor = OshiBlue,
            onClick = {
                backgroundPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
        )
        TestImagePresetRow(
            presets = OshiBackgroundTestPresets,
            onSelect = { backgroundImageUri = it },
        )

        FormSectionTitle("名前")
        WhiteCardInputField(
            value = name,
            onValueChange = { name = it },
            placeholder = "推しの名前を入力",
        )

        FormSectionTitle("性別")
        SegmentedOptionRow(
            selected = gender,
            options = OshiGenderOptions,
            onSelected = { gender = it },
        )

        FormSectionTitle("性格")
        WhiteCardInputField(
            value = personality,
            onValueChange = { personality = it },
            placeholder = "例: 明るい / クール / おっとり",
        )

        FormSectionTitle("話し方")
        WhiteCardInputField(
            value = speakingStyle,
            onValueChange = { speakingStyle = it },
            placeholder = "例: 丁寧 / 元気 / 砕けた口調",
        )

        FormSectionTitle("呼び方")
        WhiteCardInputField(
            value = userNickname,
            onValueChange = { userNickname = it },
            placeholder = "例: れんくん / マネージャー",
        )

        FormSectionTitle("詳細プロフィール")
        WhiteCardInputField(
            value = birthday,
            onValueChange = { birthday = it },
            placeholder = "例: 3月9日",
        )
        WhiteCardInputField(
            value = height,
            onValueChange = { height = it },
            placeholder = "例: 168",
            keyboardType = KeyboardType.Number,
        )
        WhiteCardInputField(
            value = hometown,
            onValueChange = { hometown = it },
            placeholder = "例: 東京 / ソウル / 福岡",
        )
        WhiteCardInputField(
            value = favoriteColor,
            onValueChange = { favoriteColor = it },
            placeholder = "例: 水色 / 黒 / ゴールド",
        )
        WhiteCardInputField(
            value = favoriteFood,
            onValueChange = { favoriteFood = it },
            placeholder = "例: オムライス / 抹茶ラテ",
        )
        WhiteCardInputField(
            value = dislikedFood,
            onValueChange = { dislikedFood = it },
            placeholder = "例: パクチー / 辛すぎるもの",
        )
        WhiteCardInputField(
            value = interestsText,
            onValueChange = { interestsText = it },
            placeholder = "例: ダンス、ゲーム、深夜ラジオ",
            singleLine = false,
            minLines = 3,
        )

        FormSectionTitle("関係性・会話設定")
        WhiteCardInputField(
            value = relationshipStatus,
            onValueChange = { relationshipStatus = it },
            placeholder = "例: 仲の良い幼なじみ / 頼れる先輩とファン",
        )
        WhiteCardInputField(
            value = relationshipDetail,
            onValueChange = { relationshipDetail = it },
            placeholder = "例: 軽口は多いけど、大事な時はちゃんと寄り添ってくれる",
            singleLine = false,
            minLines = 3,
        )
        WhiteCardInputField(
            value = sharedMemory,
            onValueChange = { sharedMemory = it },
            placeholder = "例: 初めて名前を呼んでくれたライブ終わりの会話",
            singleLine = false,
            minLines = 3,
        )
        WhiteCardInputField(
            value = signaturePhrase,
            onValueChange = { signaturePhrase = it },
            placeholder = "例: 今日も最高でいこう / ちゃんと見てるよ",
        )
        WhiteCardInputField(
            value = conversationTopicsText,
            onValueChange = { conversationTopicsText = it },
            placeholder = "例: 音楽、配信、学校生活",
            singleLine = false,
            minLines = 3,
        )
        WhiteCardInputField(
            value = forbiddenTopicsText,
            onValueChange = { forbiddenTopicsText = it },
            placeholder = "例: 炎上話、重すぎる説教、仕事の愚痴",
            singleLine = false,
            minLines = 3,
        )

        FormSectionTitle("メモ")
        WhiteCardInputField(
            value = memo,
            onValueChange = { memo = it },
            placeholder = "好きなところやプロフィールを書いてみましょう",
            singleLine = false,
            minLines = 4,
        )

        FormSectionTitle("会話言語")
        CapsuleSelectorRow(
            selected = preferredLanguage,
            options = OshiLanguageOptions,
            onSelected = { preferredLanguage = it },
        )

        PrimaryGradientButton(
            text = if (existing == null) "推しを登録" else "推しを保存",
            onClick = {
                onSave(
                    OshiDraft(
                        id = existing?.id,
                        name = name,
                        memo = memo,
                        personality = personality,
                        speakingStyle = speakingStyle,
                        birthday = birthday,
                        height = height,
                        hometown = hometown,
                        favoriteColor = favoriteColor,
                        favoriteFood = favoriteFood,
                        dislikedFood = dislikedFood,
                        interestsText = interestsText,
                        userNickname = userNickname,
                        relationshipStatus = relationshipStatus,
                        relationshipDetail = relationshipDetail,
                        sharedMemory = sharedMemory,
                        signaturePhrase = signaturePhrase,
                        conversationTopicsText = conversationTopicsText,
                        forbiddenTopicsText = forbiddenTopicsText,
                        gender = gender,
                        preferredLanguage = preferredLanguage,
                    ),
                    profileImageUri,
                    backgroundImageUri,
                )
            },
            gradientColors = listOf(OshiBlue, OshiIndigo),
        )
    }
}

@Composable
private fun ItemFormScreen(
    selectedOshi: Oshi?,
    existing: OshiItem?,
    isSaving: Boolean,
    onBack: () -> Unit,
    onSave: (OshiItemDraft, Uri?) -> Unit,
) {
    var title by remember(existing?.id) { mutableStateOf(existing?.title.orEmpty()) }
    var itemType by remember(existing?.id) { mutableStateOf(existing?.itemType ?: OshiItemTypeOptions.first()) }
    var category by remember(existing?.id) { mutableStateOf(existing?.category ?: GoodsCategoryOptions.first()) }
    var memo by remember(existing?.id) { mutableStateOf(existing?.memo.orEmpty()) }
    var price by remember(existing?.id) { mutableStateOf(existing?.price?.toString().orEmpty()) }
    var eventName by remember(existing?.id) { mutableStateOf(existing?.eventName.orEmpty()) }
    var location by remember(existing?.id) { mutableStateOf(existing?.location.orEmpty()) }
    var locationAddress by remember(existing?.id) { mutableStateOf(existing?.locationAddress.orEmpty()) }
    var details by remember(existing?.id) { mutableStateOf(existing?.details.orEmpty()) }
    var tags by remember(existing?.id) { mutableStateOf(existing?.tags?.joinToString(", ").orEmpty()) }
    var favorite by remember(existing?.id) { mutableStateOf(existing?.favorite ?: 0) }
    var itemDateMillis by remember(existing?.id) {
        mutableStateOf(((resolveItemTimestamp(existing) ?: currentTimestampSeconds()) * 1000).toLong())
    }
    var imageUri by remember(existing?.id) { mutableStateOf<Uri?>(null) }
    val context = LocalContext.current

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) {
        imageUri = it
    }

    LaunchedEffect(itemType) {
        if (itemType == "グッズ") {
            if (category.isBlank()) category = GoodsCategoryOptions.first()
        } else {
            category = ""
        }
    }

    FormScaffold(
        title = if (existing == null) "推しの投稿を追加" else "推しの投稿を編集",
        actionLabel = if (existing == null) "投稿する" else "保存する",
        onBack = onBack,
        isSaving = isSaving,
        onSave = {
            onSave(
                OshiItemDraft(
                    id = existing?.id,
                    title = title,
                    itemType = itemType,
                    category = category,
                    memo = memo,
                    price = price,
                    eventName = eventName,
                    location = location,
                    locationAddress = locationAddress,
                    details = details,
                    tags = tags,
                    favorite = favorite,
                    dateTimestamp = itemDateMillis / 1000.0,
                ),
                imageUri,
            )
        },
    ) {
        selectedOshi?.let {
            Surface(
                shape = RoundedCornerShape(999.dp),
                color = OshiSurfaceAlt,
            ) {
                Text(
                    text = "保存先: ${it.name}",
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        FormSectionTitle("投稿タイプ")
        SelectableTypeRow(
            selected = itemType,
            options = OshiItemTypeOptions,
            onSelected = {
                itemType = it
                if (it == "グッズ" && category.isBlank()) category = GoodsCategoryOptions.first()
            },
        )

        FormSectionTitle("画像")
        FormImagePickerCard(
            model = imageUri ?: existing?.imageUrl,
            placeholderIcon = Icons.Rounded.PhotoCamera,
            placeholderText = "タップして画像を選択",
            onClick = {
                picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
        )
        TestImagePresetRow(
            presets = itemImageTestPresets(itemType),
            onSelect = { imageUri = it },
        )

        FormSectionTitle("タイトル")
        SoftInputField(
            value = title,
            onValueChange = { title = it },
            placeholder = "例: BTS 公式ペンライト Ver.3",
        )

        if (itemType == "グッズ") {
            FormSectionTitle("カテゴリー")
            CapsuleSelectorRow(
                selected = category,
                options = GoodsCategoryOptions,
                onSelected = { category = it },
            )

            FormSectionTitle("価格")
            SoftInputField(
                value = price,
                onValueChange = { price = it },
                placeholder = "例: 5500",
                keyboardType = KeyboardType.Number,
            )
        }
        FormSectionTitle(dateLabelForItemType(itemType))
        DateInputField(
            timestampMillis = itemDateMillis,
            onClick = {
                val calendar = Calendar.getInstance().apply { timeInMillis = itemDateMillis }
                DatePickerDialog(
                    context,
                    { _, year, month, dayOfMonth ->
                        itemDateMillis = Calendar.getInstance().apply {
                            set(year, month, dayOfMonth, 0, 0, 0)
                            set(Calendar.MILLISECOND, 0)
                        }.timeInMillis
                    },
                    calendar.get(Calendar.YEAR),
                    calendar.get(Calendar.MONTH),
                    calendar.get(Calendar.DAY_OF_MONTH),
                ).show()
            },
        )
        if (itemType == "ライブ記録") {
            FormSectionTitle("イベント名")
            SoftInputField(
                value = eventName,
                onValueChange = { eventName = it },
                placeholder = "ライブ名やイベント名を入力",
            )
        }
        if (itemType == "聖地巡礼") {
            FormSectionTitle("住所")
            SoftInputField(
                value = locationAddress,
                onValueChange = { locationAddress = it },
                placeholder = "住所を入力",
            )
            FormSectionTitle("場所メモ")
            SoftInputField(
                value = location,
                onValueChange = { location = it },
                placeholder = "思い出の場所やスポット名",
            )
        }
        if (itemType == "SNS投稿" || itemType == "その他") {
            FormSectionTitle("詳細")
            SoftInputField(
                value = details,
                onValueChange = { details = it },
                placeholder = if (itemType == "SNS投稿") "投稿内容やURLのメモ" else "詳細を入力",
                singleLine = false,
                minLines = 3,
            )
        }

        FormSectionTitle("タグ")
        SoftInputField(
            value = tags,
            onValueChange = { tags = it },
            placeholder = "例: #限定, #ペンライト, #2025ツアー",
        )

        FormSectionTitle("お気に入り")
        FavoriteSelectorRow(
            favorite = favorite,
            onFavoriteChange = { favorite = it },
        )

        FormSectionTitle("メモ")
        SoftInputField(
            value = memo,
            onValueChange = { memo = it },
            placeholder = "感想や思い出を書いてみましょう",
            singleLine = false,
            minLines = 4,
        )
    }
}

@Composable
private fun DateInputField(
    timestampMillis: Long,
    onClick: () -> Unit,
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(18.dp),
        color = OshiSurfaceAlt,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.45f)),
    ) {
        Text(
            text = formatDate(timestampMillis / 1000.0),
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun FavoriteSelectorRow(
    favorite: Int,
    onFavoriteChange: (Int) -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        (1..5).forEach { index ->
            Icon(
                imageVector = if (index <= favorite) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
                contentDescription = "お気に入り$index",
                tint = if (index <= favorite) OshiPink else OshiTextMuted,
                modifier = Modifier
                    .size(28.dp)
                    .clickable { onFavoriteChange(index) },
            )
        }
        if (favorite > 0) {
            TextButton(onClick = { onFavoriteChange(0) }) {
                Text("クリア", color = OshiTextMuted)
            }
        }
    }
}

@Composable
private fun LocationFormScreen(
    selectedOshi: Oshi?,
    existing: EventLocation?,
    isSaving: Boolean,
    onBack: () -> Unit,
    onSave: (EventLocationDraft, Uri?) -> Unit,
) {
    var title by remember(existing?.id) { mutableStateOf(existing?.title.orEmpty()) }
    var category by remember(existing?.id) { mutableStateOf(existing?.category ?: LocationCategoryOptions.first()) }
    var note by remember(existing?.id) { mutableStateOf(existing?.note.orEmpty()) }
    var latitude by remember(existing?.id) { mutableStateOf(existing?.latitude?.toString().orEmpty()) }
    var longitude by remember(existing?.id) { mutableStateOf(existing?.longitude?.toString().orEmpty()) }
    var prefecture by remember(existing?.id) { mutableStateOf("") }
    var streetAddress by remember(existing?.id) { mutableStateOf(existing?.locationAddress.orEmpty()) }
    var buildingName by remember(existing?.id) { mutableStateOf("") }
    var imageUri by remember(existing?.id) { mutableStateOf<Uri?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) {
        imageUri = it
    }

    val composedAddress = listOf(prefecture, streetAddress, buildingName)
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .joinToString(" ")

    FormScaffold(
        title = if (existing == null) "推しスポットを登録" else "スポットを編集",
        actionLabel = "保存",
        onBack = onBack,
        isSaving = isSaving,
        containerColor = Color(0xFFF7F7FA),
        onSave = {
            onSave(
                EventLocationDraft(
                    id = existing?.id,
                    title = title,
                    category = category,
                    note = note,
                    latitude = latitude,
                    longitude = longitude,
                    locationAddress = composedAddress.ifBlank { streetAddress.trim() },
                ),
                imageUri,
            )
        },
    ) {
        selectedOshi?.let {
            Surface(
                shape = RoundedCornerShape(24.dp),
                color = Color.White,
                shadowElevation = 8.dp,
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(locationCategoryColor(category).copy(alpha = 0.12f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Rounded.Place, contentDescription = null, tint = locationCategoryColor(category))
                    }
                    Column {
                        Text(
                            text = "保存先",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            text = it.name,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
        }

        FormSectionTitle("スポット画像")
        FormImagePickerCard(
            model = imageUri ?: existing?.imageURL,
            placeholderIcon = Icons.Rounded.Place,
            placeholderText = "タップして画像を選択",
            accentColor = locationCategoryColor(category),
            onClick = {
                picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
        )
        TestImagePresetRow(
            presets = LocationImageTestPresets,
            onSelect = { imageUri = it },
        )

        FormSectionTitle("カテゴリ")
        LocationCategorySelectorRow(
            options = LocationCategoryOptions,
            selected = category,
            onSelected = { category = it },
        )

        FormSectionTitle("スポット名")
        WhiteCardInputField(
            value = title,
            onValueChange = { title = it },
            placeholder = "場所のタイトルを入力",
        )

        FormSectionTitle("住所")
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            WhiteCardInputField(
                value = prefecture,
                onValueChange = { prefecture = it },
                placeholder = "都道府県",
            )
            WhiteCardInputField(
                value = streetAddress,
                onValueChange = { streetAddress = it },
                placeholder = "市区町村・番地",
            )
            WhiteCardInputField(
                value = buildingName,
                onValueChange = { buildingName = it },
                placeholder = "施設名・ビル名",
            )
        }

        FormSectionTitle("地図の位置")
        Surface(
            shape = RoundedCornerShape(28.dp),
            color = Color.White,
            shadowElevation = 10.dp,
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                        .clip(RoundedCornerShape(24.dp))
                        .background(Color.White),
                ) {
                    LeafletMapView(
                        locations = listOf(
                            EventLocation(
                                id = existing?.id ?: "preview",
                                title = title.ifBlank { "新しいスポット" },
                                latitude = latitude.toDoubleOrNull() ?: 35.6809591,
                                longitude = longitude.toDoubleOrNull() ?: 139.7673068,
                                imageURL = imageUri?.toString() ?: existing?.imageURL,
                                category = category,
                                note = note.ifBlank { null },
                                locationAddress = composedAddress.ifBlank { null },
                            ),
                        ),
                        selectedLocationId = existing?.id ?: "preview",
                        modifier = Modifier.fillMaxSize(),
                        onSelect = {},
                    )
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .fillMaxWidth()
                            .height(108.dp)
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(Color.White.copy(alpha = 0.9f), Color.Transparent),
                                ),
                            ),
                    )
                    Column(
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text(
                            text = if (composedAddress.isBlank()) "住所を入力するとここに表示されます" else composedAddress,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = "緯度と経度を入力すると、スポット位置の目安として使えます。",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    WhiteCardInputField(
                        value = latitude,
                        onValueChange = { latitude = it },
                        placeholder = "緯度",
                        keyboardType = KeyboardType.Decimal,
                        modifier = Modifier.weight(1f),
                    )
                    WhiteCardInputField(
                        value = longitude,
                        onValueChange = { longitude = it },
                        placeholder = "経度",
                        keyboardType = KeyboardType.Decimal,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }

        FormSectionTitle("メモ")
        WhiteCardInputField(
            value = note,
            onValueChange = { note = it },
            placeholder = "思い出や補足メモ",
            singleLine = false,
            minLines = 5,
        )
    }
}

@Composable
private fun LocationCategorySelectorRow(
    selected: String,
    options: List<String>,
    onSelected: (String) -> Unit,
) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        items(options) { option ->
            val color = locationCategoryColor(option)
            val isSelected = selected == option
            Surface(
                modifier = Modifier.clickable { onSelected(option) },
                shape = RoundedCornerShape(999.dp),
                color = if (isSelected) color.copy(alpha = 0.16f) else Color.White,
                border = BorderStroke(1.dp, if (isSelected) color else OshiSurfaceAlt),
                shadowElevation = if (isSelected) 4.dp else 0.dp,
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(color),
                    )
                    Text(
                        text = option,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (isSelected) color else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

private fun mapMarkerFractions(
    locations: List<EventLocation>,
    location: EventLocation,
): Pair<Float, Float> {
    if (locations.size <= 1) return 0.5f to 0.52f

    val minLat = locations.minOf { it.latitude }
    val maxLat = locations.maxOf { it.latitude }
    val minLng = locations.minOf { it.longitude }
    val maxLng = locations.maxOf { it.longitude }

    val x = if (maxLng - minLng < 0.00001) {
        0.5f
    } else {
        ((location.longitude - minLng) / (maxLng - minLng)).toFloat().coerceIn(0.14f, 0.86f)
    }

    val y = if (maxLat - minLat < 0.00001) {
        0.5f
    } else {
        (1f - ((location.latitude - minLat) / (maxLat - minLat)).toFloat()).coerceIn(0.24f, 0.78f)
    }

    return x to y
}

private fun locationCategoryColor(category: String): Color = when (category) {
    "聖地巡礼" -> Color(0xFFEF4444)
    "撮影スポット" -> OshiPink
    "カフェ・飲食店" -> Color(0xFF10B981)
    "ライブ会場" -> OshiBlue
    "グッズショップ" -> Color(0xFFF59E0B)
    else -> OshiPurple
}

@Composable
private fun GradientFab(
    onClick: () -> Unit,
    contentDescription: String,
) {
    Box(
        modifier = Modifier
            .size(72.dp)
            .shadow(18.dp, CircleShape)
            .clip(CircleShape)
            .background(Brush.linearGradient(listOf(OshiPink, OshiPurple)))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Rounded.Add,
            contentDescription = contentDescription,
            tint = Color.White,
            modifier = Modifier.size(32.dp),
        )
    }
}

private fun filterLogItems(
    items: List<OshiItem>,
    query: String,
    itemType: String,
    category: String,
    sortOption: String,
): List<OshiItem> {
    val normalized = query.trim().lowercase()
    val filtered = items.filter { item ->
        val queryMatched = normalized.isBlank() || listOf(
            item.title,
            item.memo,
            item.eventName,
            item.locationAddress,
            item.details,
            item.category,
            item.itemType,
            item.tags?.joinToString(" "),
        ).any { value ->
            value?.lowercase()?.contains(normalized) == true
        }

        val typeMatched = itemType == ItemTypeFilterOptions.first() || item.itemType == itemType
        val categoryMatched = category == CategoryFilterOptions.first() || item.category == category

        queryMatched && typeMatched && categoryMatched
    }

    return when (sortOption) {
        "古い順" -> filtered.sortedBy { resolveItemTimestamp(it) ?: 0.0 }
        "価格高い順" -> filtered.sortedByDescending { it.price ?: 0 }
        "価格安い順" -> filtered.sortedBy { it.price ?: Int.MAX_VALUE }
        "お気に入り順" -> filtered.sortedByDescending { it.favorite ?: 0 }
        else -> filtered.sortedByDescending { resolveItemTimestamp(it) ?: 0.0 }
    }
}

private fun shareItem(
    context: Context,
    item: OshiItem,
) {
    val shareText = buildString {
        append(item.title ?: "推しの投稿")
        item.itemType?.takeIf { it.isNotBlank() }?.let { append("\n$it") }
        item.memo?.takeIf { it.isNotBlank() }?.let { append("\n$it") }
    }
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, shareText)
    }
    context.startActivity(Intent.createChooser(intent, "投稿を共有"))
}

@Composable
private fun FormScaffold(
    title: String,
    actionLabel: String = "保存",
    onBack: () -> Unit,
    isSaving: Boolean,
    containerColor: Color = Color.White,
    onSave: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(containerColor),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier.weight(1f),
                contentAlignment = Alignment.CenterStart,
            ) {
                TextButton(onClick = onBack, contentPadding = PaddingValues(horizontal = 4.dp, vertical = 6.dp)) {
                    Icon(
                        Icons.AutoMirrored.Rounded.ArrowBack,
                        contentDescription = "戻る",
                        tint = OshiPink,
                    )
                    Text(
                        "戻る",
                        color = OshiPink,
                        style = MaterialTheme.typography.headlineSmall,
                    )
                }
            }
            Box(
                modifier = Modifier.weight(1.6f),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                )
            }
            Box(
                modifier = Modifier.weight(1f),
                contentAlignment = Alignment.CenterEnd,
            ) {
                TextButton(onClick = onSave, enabled = !isSaving, contentPadding = PaddingValues(horizontal = 6.dp, vertical = 6.dp)) {
                    Text(
                        text = actionLabel,
                        color = if (isSaving) OshiTextMuted else OshiPink,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }

        if (isSaving) {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 8.dp, bottom = 42.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
            content = content,
        )
    }
}
